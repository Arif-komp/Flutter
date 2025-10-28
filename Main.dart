import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart'; // Import scanner
import 'package:flutter/services.dart'; // Untuk mengontrol fokus

void main() {
  runApp(const StockCheckerApp());
}

class StockCheckerApp extends StatelessWidget {
  const StockCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cek Stok Smart',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF007bff),
          foregroundColor: Colors.white,
        ),
      ),
      home: const StockCheckerScreen(),
    );
  }
}

class StockCheckerScreen extends StatefulWidget {
  const StockCheckerScreen({super.key});

  @override
  State<StockCheckerScreen> createState() => _StockCheckerScreenState();
}

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

class _StockCheckerScreenState extends State<StockCheckerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<StockItem> _allData = [];
  List<StockItem> _filteredData = [];
  String _message = 'Memuat data dari Google Sheet...';
  Color _messageColor = Colors.grey;

  // GANTI DENGAN ID GOOGLE SHEET ANDA
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
    super.dispose();
  }

  // --- FUNGSI AMBIL DATA DART ---
  Future<void> _fetchData() async {
    try {
      final response = await http.get(Uri.parse(_url));
      if (response.statusCode != 200) {
        throw Exception('Gagal mengambil data (HTTP ${response.statusCode})');
      }

      // Parsing JSON dari format Google Sheet Query
      String text = response.body.substring(response.body.indexOf('(') + 1, response.body.lastIndexOf(')'));
      final data = json.decode(text);

      List<StockItem> loadedData = [];
      if (data['table'] != null && data['table']['rows'] != null) {
        for (var row in data['table']['rows']) {
          final cells = row['c'];
          
          String getCellValue(int index, bool isFormatted) {
            if (cells[index] != null) {
              return isFormatted && cells[index]['f'] != null ? cells[index]['f'].toString() : cells[index]['v']?.toString() ?? '';
            }
            return '';
          }

          final barcode = getCellValue(0, false);
          final produk = getCellValue(1, false);
          final lokasi = getCellValue(2, false);
          final tglEd = getCellValue(3, true); // Ambil format tanggal
          final qty = getCellValue(4, true);  // Ambil format angka

          if (barcode.isNotEmpty || produk.isNotEmpty) {
             // Melewatkan baris header jika ada
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
        _messageColor = Colors.red[700]!;
      });
      print('Error fetching data: $e');
    }
  }

  // --- FUNGSI PENCARIAN DART ---
  void _onSearchChanged() {
    final searchTerm = _searchController.text.toLowerCase().trim();
    if (searchTerm.isEmpty) {
      setState(() {
        _filteredData = [];
        _message = 'Masukkan minimal 3 karakter (Barcode/Nama Produk), atau gunakan Scan Kamera.';
        _messageColor = const Color(0xFF6c757d);
      });
      return;
    }
    
    // Logika ini mendukung scanner fisik yang sering mengirim input cepat atau diikuti Enter
    if (searchTerm.length < 3 && !searchTerm.contains('\n')) {
      setState(() {
        _filteredData = [];
        _message = 'Masukkan minimal 3 karakter (Barcode/Nama Produk), atau gunakan Scan Kamera.';
        _messageColor = const Color(0xFF6c757d);
      });
      return;
    }

    final keywords = searchTerm.split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();

    final filtered = _allData.where((item) {
      final searchString = (item.barcode + " " + item.produk + " " + item.lokasi).toLowerCase();
      return keywords.every((keyword) => searchString.contains(keyword));
    }).toList();

    setState(() {
      _filteredData = filtered;
      if (filtered.isEmpty) {
        _message = '⚠️ Tidak ada data ditemukan untuk "$searchTerm". Coba kata kunci lain.';
        _messageColor = Colors.orange[700]!;
      } else {
        _message = ''; // Sembunyikan pesan jika ada hasil
      }
    });
  }

  // --- FUNGSI MULAI SCANNER DART (MOBILE SCANNER) ---
  void _startBarcodeScan(BuildContext context) async {
    // Navigasi ke halaman scanner
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerOverlay()),
    );

    if (result != null && result is String) {
      // Hasil scan dikembalikan
      _searchController.text = result;
      _onSearchChanged(); // Lakukan pencarian otomatis
      
      setState(() {
        _message = '✅ Barcode $result berhasil di-scan! Mencari data...';
        _messageColor = Colors.green[700]!;
      });
      // Mengatur fokus kembali ke input setelah scan
      FocusScope.of(context).requestFocus(_searchFocusNode); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CEK STOK SMART')),
      body: Container(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: <Widget>[
            // 1. INPUT DAN SCAN BUTTON
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, width: 2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Input Barcode atau Nama Produk...',
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 16),
                      // Listener untuk tombol enter pada keyboard fisik/scanner
                      onSubmitted: (_) => _onSearchChanged(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF007bff)),
                    onPressed: () => _startBarcodeScan(context),
                    tooltip: 'Scan Barcode',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
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
            const Text('DETAIL ITEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6c757d))),
            const SizedBox(height: 5),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 10,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 50,
                  headingRowColor: MaterialStateProperty.resolveWith((states) => const Color(0xFF007bff)),
                  columns: const [
                    DataColumn(label: Text('Nama Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('LOK.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Tgl ED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: _filteredData.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item.produk, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                        DataCell(Text(item.lokasi, style: const TextStyle(fontSize: 14))),
                        DataCell(Text(item.tglEd, style: const TextStyle(fontSize: 14))),
                        DataCell(Text(item.qty, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14), textAlign: TextAlign.center)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SCANNER OVERLAY DART (Contoh Implementasi Mobile Scanner) ---
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        controller: MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          // Hanya fokus pada format barcode umum EAN dan CODE128 (default)
        ),
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String scannedCode = barcodes.first.rawValue ?? 'N/A';
            if (scannedCode != 'N/A') {
              // Mengembalikan hasil scan ke halaman sebelumnya
              Navigator.pop(context, scannedCode);
            }
          }
        },
      ),
    );
  }
}
