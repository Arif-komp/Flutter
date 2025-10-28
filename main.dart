import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Diperlukan untuk Timer
import 'package:mobile_scanner/mobile_scanner.dart'; // Digunakan untuk scan kamera

void main() {
  runApp(const StockCheckerApp());
}

// ==========================================================
// MODEL DATA
// ==========================================================
class StockItem {
  final String barcode;
  final String produk;
  final String lokasi;
  final String tglEd;
  final String qty;

  StockItem({
    required this.barcode,
    required this.produk,
    required this.lokasi,
    required this.tglEd,
    required this.qty,
  });
}

// ==========================================================
// APLIKASI UTAMA
// ==========================================================
class StockCheckerApp extends StatelessWidget {
  const StockCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cek Stok Smart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF007bff), // Primary Color
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF007bff),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 20
          ),
        ),
      ),
      home: const StockCheckerScreen(),
    );
  }
}

// ==========================================================
// LAYAR UTAMA
// ==========================================================
class StockCheckerScreen extends StatefulWidget {
  const StockCheckerScreen({super.key});

  @override
  State<StockCheckerScreen> createState() => _StockCheckerScreenState();
}

class _StockCheckerScreenState extends State<StockCheckerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<StockItem> _allData = [];
  List<StockItem> _filteredData = [];
  String _message = 'Memuat data dari Google Sheet...';
  Color _messageColor = Colors.orange;

  // --- GANTI DENGAN ID GOOGLE SHEET ANDA SENDIRI ---
  static const String sheetId = '1qA2INHulKAM3UXnelYqw1eg_fDRHOXzeM_R2_wMqXj4';
  static const String sheetName = 'sheet1';
  final String _url =
      'https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:json&sheet=$sheetName';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // --- FUNGSI AMBIL DATA DART ---
  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse(_url));
      if (response.statusCode != 200) {
        throw Exception('Gagal mengambil data (HTTP ${response.statusCode})');
      }

      // Memotong string untuk mendapatkan JSON murni
      String text = response.body.substring(response.body.indexOf('(') + 1, response.body.lastIndexOf(')'));
      final data = json.decode(text);

      List<StockItem> loadedData = [];
      if (data['table'] != null && data['table']['rows'] != null) {
        for (var row in data['table']['rows']) {
          final cells = row['c'];
          
          String getCellValue(int index, bool isFormatted) {
            if (cells.length > index && cells[index] != null) {
              return isFormatted && cells[index]['f'] != null ? cells[index]['f'].toString() : cells[index]['v']?.toString() ?? '';
            }
            return '';
          }

          final barcode = getCellValue(0, false);
          final produk = getCellValue(1, false);
          final lokasi = getCellValue(2, false);
          final tglEd = getCellValue(3, true); 
          final qty = getCellValue(4, true);  

          if (barcode.isNotEmpty || produk.isNotEmpty) {
            // Melewatkan baris header berdasarkan isi konten
            if (barcode.toLowerCase() != 'barcode' && produk.toLowerCase() != 'nama produk') {
              loadedData.add(
                StockItem(
                  barcode: barcode,
                  produk: produk,
                  lokasi: lokasi.isNotEmpty ? lokasi : 'N/A',
                  tglEd: tglEd.isNotEmpty ? tglEd : 'N/A',
                  qty: qty.isNotEmpty ? qty : '0',
                ),
              );
            }
          }
        }
      }

      setState(() {
        _allData = loadedData;
        _filteredData = [];
        _message = 'Masukkan Barcode atau Nama Produk untuk mencari item.';
        _messageColor = const Color(0xFF6c757d);
      });
    } catch (e) {
      setState(() {
        _message = '❌ Error: Gagal memuat data. Periksa koneksi atau ID Sheet.';
        _messageColor = const Color(0xFFdc3545);
      });
      print('Error fetching data: $e');
    }
  }

  // --- FUNGSI PENCARIAN DART ---
  void _onSearchChanged() {
    final searchTerm = _searchController.text.toLowerCase().trim();
    
    // Logika untuk scanner fisik (biasanya diakhiri Enter)
    if (searchTerm.endsWith('\n')) {
      _searchController.text = searchTerm.substring(0, searchTerm.length - 1);
      _searchController.selection = TextSelection.fromPosition(TextPosition(offset: _searchController.text.length));
      return _performSearch(_searchController.text.trim());
    }

    if (searchTerm.isEmpty || searchTerm.length < 3) {
      setState(() {
        _filteredData = [];
        _message = 'Masukkan minimal 3 karakter (Barcode/Nama Produk), atau gunakan Scan Kamera.';
        _messageColor = const Color(0xFF6c757d);
      });
      return;
    }
    
    // debounce (digunakan untuk input keyboard manual agar tidak mencari setiap ketikan)
    if (_searchTimer != null && _searchTimer!.isActive) _searchTimer!.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(searchTerm);
    });
  }

  // Timer untuk debounce
  Timer? _searchTimer;
  
  void _performSearch(String searchTerm) {
      final keywords = searchTerm.split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();

      final filtered = _allData.where((item) {
        final searchString = (item.barcode + " " + item.produk + " " + item.lokasi).toLowerCase();
        return keywords.every((keyword) => searchString.contains(keyword));
      }).toList();

      setState(() {
        _filteredData = filtered;
        if (filtered.isEmpty) {
          _message = '⚠️ Tidak ada data ditemukan untuk "$searchTerm". Coba kata kunci lain.';
          _messageColor = const Color(0xFFffc107); // Kuning
        } else {
          _message = ''; 
        }
      });
  }

  // --- FUNGSI MULAI SCANNER DART ---
  void _startBarcodeScan(BuildContext context) async {
    // Navigasi ke halaman scanner
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerOverlay()),
    );

    if (result != null && result is String) {
      // Hasil scan dikembalikan
      _searchController.text = result;
      _performSearch(result); // Lakukan pencarian otomatis
      
      setState(() {
        _message = '✅ Barcode $result berhasil di-scan! Mencari data...';
        _messageColor = const Color(0xFF28a745); // Hijau
      });
      // Mengatur fokus kembali ke input setelah scan
      FocusScope.of(context).requestFocus(_searchFocusNode); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 30),
            
            // Header dan Logo
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 15),
                  child: Image.asset('assets/smart.png', fit: BoxFit.contain), 
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CEK STOK SMART', 
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w700, 
                          color: Theme.of(context).primaryColor
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 30),
            
            // 1. INPUT DAN SCAN BUTTON
            const Text('SCAN / INPUT BARCODE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6c757d), letterSpacing: 0.5)),
            Container(
              margin: const EdgeInsets.only(top: 5, bottom: 15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, width: 2),
                borderRadius: BorderRadius.circular(8.0),
                color: const Color(0xFFf8f9fa)
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'Input Barcode atau Nama Produk...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 16),
                        onSubmitted: (value) => _performSearch(value.trim()),
                        textInputAction: TextInputAction.search, // Mengubah tombol enter di mobile
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _startBarcodeScan(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                      ),
                      child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            
            // 2. PESAN STATUS
            if (_message.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: _messageColor.withOpacity(0.1),
                  border: Border.all(color: _messageColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_message, style: TextStyle(color: _messageColor, fontStyle: FontStyle.italic)),
              ),

            // 3. TABEL DATA
            const Text('DETAIL ITEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6c757d), letterSpacing: 0.5)),
            const SizedBox(height: 15),
            
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFe9ecef)),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3, offset: const Offset(0, 1))]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      // Header Tabel
                      Container(
                        color: Theme.of(context).primaryColor,
                        child: Row(
                          children: _buildHeaderCells(),
                        ),
                      ),
                      // Baris Data
                      if (_filteredData.isEmpty && _message.isEmpty)
                        Container(
                          width: MediaQuery.of(context).size.width - 40, // Lebar container - padding
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.center,
                          child: const Text('Tidak ada data item ditemukan.', style: TextStyle(color: Color(0xFF6c757d), fontStyle: FontStyle.italic)),
                        ),
                      ..._filteredData.map((item) => _buildDataRow(item)).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper untuk membuat Header Tabel (Agar sticky di web)
  List<Widget> _buildHeaderCells() {
    // PERUBAHAN UKURAN KOLOM:
    // Nama Produk: Diperlebar dari 250 menjadi 280
    // Tgl ED: Dikecilkan dari 120 menjadi 90
    return [
      _buildHeaderCell('Nama Produk', 380),
      _buildHeaderCell('LOK.', 80),
      _buildHeaderCell('Tgl ED', 55),
      _buildHeaderCell('Qty', 60),
    ];
  }

  Widget _buildHeaderCell(String text, double width) {
    // PERUBAHAN PERATAAN TEKS HEADER:
    // Dibuat rata tengah (Alignment.center)
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      alignment: Alignment.center, // <-- MODIFIKASI: Rata Tengah
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF0056b3), width: 0.5)
      ),
      child: Text(
        text, 
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  // Helper untuk membuat Baris Data
  Widget _buildDataRow(StockItem item) {
    // PERUBAHAN UKURAN KOLOM:
    // Nama Produk: Diperlebar dari 250 menjadi 280
    // Tgl ED: Dikecilkan dari 120 menjadi 90
    return Container(
      color: _filteredData.indexOf(item) % 2 == 0 ? Colors.white : const Color(0xFFf3f5f8),
      child: Row(
        children: [
          _buildDataCell(item.produk, 350, fontWeight: FontWeight.w500),
          _buildDataCell(item.lokasi, 80, align: Alignment.center),
          _buildDataCell(item.tglEd, 50, align: Alignment.center),
          _buildDataCell(item.qty, 60, align: Alignment.center, fontWeight: FontWeight.w700),
        ],
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {Alignment align = Alignment.centerLeft, FontWeight fontWeight = FontWeight.normal}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      alignment: align,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFe9ecef), width: 1))
      ),
      child: Text(
        text, 
        style: TextStyle(fontSize: 14, fontWeight: fontWeight, color: const Color(0xFF212529)),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }
}

// ==========================================================
// LAYAR SCANNER (Menggunakan mobile_scanner)
// ==========================================================
class ScannerOverlay extends StatefulWidget {
  const ScannerOverlay({super.key});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> {
  // PENGATURAN UNTUK SCANNER SENSITIF: 
  // detectionSpeed: DetectionSpeed.normal menganalisis lebih banyak frame per detik
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal, // <-- MODIFIKASI: Deteksi lebih sering
    returnImage: false,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController.torchState,
              builder: (context, state, child) {
                switch (state as TorchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.white);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController, 
            onDetect: (capture) {
              if (_isProcessing) return; 

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String scannedCode = barcodes.first.rawValue ?? '';
                
                if (scannedCode.isNotEmpty) {
                  setState(() => _isProcessing = true);
                  
                  _scannerController.stop(); 
                  Navigator.pop(context, scannedCode);
                }
              }
            },
          ),
          // Tambahkan overlay visual (seperti kotak scan)
          Center(
            child: Container(
              // MODIFIKASI UKURAN KOTAK SCAN: diperbesar
              width: 300,
              height: 3000, // <-- MODIFIKASI: Ditingkatkan dari 80 menjadi 150
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 3),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Text(
              'Arahkan kamera ke Barcode (Flash tersedia di pojok kanan atas)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
