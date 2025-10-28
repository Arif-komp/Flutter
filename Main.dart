import 'package:flutter/material.dart';
// Asumsi menggunakan package mobile_scanner untuk scanning
// import 'package:mobile_scanner/mobile_scanner.dart'; 

// Model data produk yang mungkin didapatkan setelah scan
class ProductData {
  final String barcode;
  final String productName;
  final String expiryDate;
  final String stock;

  ProductData({
    required this.barcode,
    required this.productName,
    required this.expiryDate,
    required this.stock,
  });
}

void main() {
  runApp(const BarcodeScannerApp());
}

class BarcodeScannerApp extends StatelessWidget {
  const BarcodeScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barcode Scanner Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BarcodeScannerScreen(),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Data dummy yang didapatkan setelah simulasi scan
  List<ProductData> scannedProducts = [
    ProductData(
      barcode: '8992745300010', // Contoh UPC/EAN dari aplikasi terkenal
      productName: 'Susu Bubuk Full Cream 1kg',
      expiryDate: '2025-12-31',
      stock: '150',
    ),
    ProductData(
      barcode: '9780321765723',
      productName: 'Mie Instan Rasa Soto (Isi 40)',
      expiryDate: '2024-10-28',
      stock: '25',
    ),
  ];
  
  // Variabel untuk mengontrol tampilan kamera (simulasi)
  bool isScanning = false; 
  
  // Fungsi simulasi hasil scan
  void _simulateScan() {
    setState(() {
      isScanning = true;
    });
    // Setelah beberapa detik, simulasikan hasil scan
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isScanning = false;
          // Asumsi hasil scan menambahkan item ke list
          if (scannedProducts.length < 3) {
             scannedProducts.add(
                ProductData(
                  barcode: '5010255010001',
                  productName: 'Kopi Instant Black Coffee (Box)',
                  expiryDate: '2026-06-15',
                  stock: '88',
                ),
            );
          }
        });
        // Tampilkan pesan atau lakukan navigasi jika perlu
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barcode berhasil di-scan!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Implementasi sensitifitas (memfilter format barcode) di Flutter biasanya dilakukan 
    // dengan menentukan `allowedFormats` pada konfigurasi scanner, yang meningkatkan 
    // fokus dan kecepatan deteksi pada jenis kode yang spesifik (mirip dengan aplikasi terkenal).
    // Contoh untuk paket mobile_scanner:
    // final List<BarcodeFormat> retailFormats = [
    //   BarcodeFormat.ean13,
    //   BarcodeFormat.upcA,
    //   // ... format ritel lainnya
    // ];

    return Scaffold(
      appBar: AppBar(
        // Bagian ini dikosongkan untuk memindahkan judul ke body (Perintah 2)
        toolbarHeight: 0, 
      ),
      body: Column(
        children: <Widget>[
          // =========================================================
          // PERINTAH 2: Posisi logo dan judul berada di tengah
          // =========================================================
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Icon(Icons.inventory, size: 40, color: Colors.blue), // Logo
                  SizedBox(height: 8),
                  Text(
                    'Manajemen Stok Cepat', // Judul
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          // =========================================================
          // PERINTAH 1: Kamera Scan Barcode (Simulasi dengan Konfigurasi Sensitifitas)
          // =========================================================
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.black12,
            ),
            child: isScanning 
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                )
              : Center(
                  // Area di mana MobileScanner seharusnya diletakkan dengan konfigurasi:
                  /*
                  * MobileScanner(
                  * allowedFormats: retailFormats, // Meningkatkan sensitifitas/fokus
                  * onDetect: (barcodeCapture) { ... }
                  * )
                  */
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 50, color: Colors.blueGrey),
                      const Text('Area Kamera Scan Barcode', style: TextStyle(color: Colors.blueGrey)),
                      const Text('Sensitifitas (fokus format ritel) aktif.', style: TextStyle(color: Colors.green, fontSize: 12)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _simulateScan,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Mulai Scan'),
                      ),
                    ],
                  ),
                ),
          ),
          const SizedBox(height: 16),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Hasil Scan Produk:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          
          // =========================================================
          // Daftar Produk Scanned (Tabel)
          // =========================================================
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Table(
                  border: TableBorder.all(color: Colors.black26),
                  columnWidths: const {
                    0: FlexColumnWidth(1.5), // Barcode
                    // PERINTAH 3: Nama Produk dilebarkan
                    1: FlexColumnWidth(4.5), 
                    // PERINTAH 3: Tgl Ed dikecilkan
                    2: FlexColumnWidth(2.0), 
                    3: FlexColumnWidth(1.5), // Stock
                  },
                  children: [
                    // Header Tabel
                    const TableRow(
                      decoration: BoxDecoration(color: Colors.lightBlueAccent),
                      children: [
                        TableCell(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Barcode', style: TextStyle(fontWeight: FontWeight.bold)))),
                        TableCell(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Nama Produk', style: TextStyle(fontWeight: FontWeight.bold)))),
                        TableCell(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Tgl Ed', style: TextStyle(fontWeight: FontWeight.bold)))),
                        TableCell(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Stok', style: TextStyle(fontWeight: FontWeight.bold)))),
                      ],
                    ),
                    // Data Baris
                    ...scannedProducts.map((product) {
                      return TableRow(
                        children: [
                          TableCell(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(product.barcode, style: const TextStyle(fontSize: 12)))),
                          TableCell(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(product.productName))),
                          TableCell(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(product.expiryDate, style: const TextStyle(fontSize: 12)))),
                          TableCell(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(product.stock, textAlign: TextAlign.center))),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
