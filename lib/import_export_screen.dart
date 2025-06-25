import 'package:desktop/database_helper.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class ExcelToDataTable extends StatefulWidget {
  const ExcelToDataTable({super.key});

  @override
  _ExcelToDataTableState createState() => _ExcelToDataTableState();
}

class _ExcelToDataTableState extends State<ExcelToDataTable> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadFromDatabase();
  }
  bool skipFirstRow = true;

  List<DataRow> rows = [];
  List<DataColumn> columns = [];

  void pickAndReadExcel3() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null) {
      final path = result.files.single.path!;
      print(path);
      final bytes = await File(path).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables[excel.tables.keys.first];
      if (table != null) {
        final rowsRaw = table.rows;

        // 🟨 Conditionally skip first row
        final dataRows = skipFirstRow ? rowsRaw.skip(1).toList() : rowsRaw;

        // Clear previous data
        DatabaseHelper.instance.clearAll();

        for (var row in dataRows) {

          if (row.every((cell) => cell?.value == null)) continue;

          Map<String, String> rowMap = {
            'sr': row.isNotEmpty ? row[0]?.value.toString() ?? '' : '',
            'name': row.length > 1 ? row[1]?.value.toString() ?? '' : '',
            'designation': row.length > 2 ? row[2]?.value.toString() ?? '' : '',
            'joining_date': row.length > 3 ? row[3]?.value.toString() ?? '' : '',
            'gross_salary': row.length > 4 ? row[4]?.value.toString() ?? '' : '',
            'perks': row.length > 5 ? row[5]?.value.toString() ?? '' : '',
            'salary': row.length > 6 ? row[6]?.value.toString() ?? '' : '',
          };
          print("Inserting: $rowMap"); // 👈 Add this for debugging

          DatabaseHelper.instance.insertEmployee(rowMap);
        }

        // Fetch back for DataTable
        loadFromDatabase();
      }
    }
  }

  void loadFromDatabase() {
    final data = DatabaseHelper.instance.getAllEmployees();

    final filteredData = searchTerm.isEmpty
        ? data
        : data.where((row) {
      return row.values.any(
              (value) => value.toLowerCase().contains(searchTerm));
    }).toList();
    setState(() {
      columns = [
        DataColumn(label: Text("Sr")),
        DataColumn(label: Text("Name")),
        DataColumn(label: Text("Designation")),
        DataColumn(label: Text("Joining Date")),
        DataColumn(label: Text("Gross Salary")),
        DataColumn(label: Text("Perks")),
        DataColumn(label: Text("Salary")),
        DataColumn(label: Text("Actions")),
      ];
      rows = filteredData.map((row) {
        return DataRow(cells: [
          DataCell(Text(row['sr'] ?? '')),
          DataCell(Text(row['name'] ?? '')),
          DataCell(Text(row['designation'] ?? '')),
          DataCell(Text(row['joining_date'] ?? '')),
          DataCell(Text(row['gross_salary'] ?? '')),
          DataCell(Text(row['perks'] ?? '')),
          DataCell(Text(row['salary'] ?? '')),
          DataCell(Row(
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditDialog(row),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteRow(row['sr'].toString()),
              ),
            ],
          )),
        ]);
      }).toList();
    });
  }

  void _deleteRow(String sr) {
    DatabaseHelper.instance.deleteEmployee(sr);
    loadFromDatabase();
  }

  Future<void> exportToExcel(List<DataRow> rows, List<DataColumn> columns) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    List<CellValue?> convertRowToCellValues(List<String?> row) {
      return row.map((v) => TextCellValue(v ?? '')).toList();
    }

    // Add header
    sheetObject.appendRow(
      convertRowToCellValues(columns.map((c) => c.label is Text ? (c.label as Text).data : "").toList()),
    );

    // Apply Style to Header
    CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.black26,
      fontFamily: getFontFamily(FontFamily.Calibri),
    );
    List<String?> headerLabels = columns.map((c) => c.label is Text ? (c.label as Text).data : "").toList();

    for (int col = 0; col < headerLabels.length; col++) {
      final cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    // Add rows
    for (var row in rows) {
      sheetObject.appendRow(
        convertRowToCellValues(
          row.cells.map((cell) {
            return cell.child is Text ? (cell.child as Text).data : "";
          }).toList(),
        ),
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/exported_file.xlsx";

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      print("Exported to: $filePath");
    }
  }

  TextEditingController searchController = TextEditingController();
  String searchTerm = "";

  void _showEditDialog(Map<String, String> row) {
    TextEditingController name = TextEditingController(text: row['name']);
    TextEditingController desig = TextEditingController(text: row['designation']);
    TextEditingController date = TextEditingController(text: row['joining_date']);
    TextEditingController gross = TextEditingController(text: row['gross_salary']);
    TextEditingController perks = TextEditingController(text: row['perks']);
    TextEditingController salary = TextEditingController(text: row['salary']);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("Update Row"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: name, decoration: InputDecoration(labelText: 'Name')),
                TextField(controller: desig, decoration: InputDecoration(labelText: 'Designation')),
                TextField(controller: date, decoration: InputDecoration(labelText: 'Joining Date')),
                TextField(controller: gross, decoration: InputDecoration(labelText: 'Gross Salary')),
                TextField(controller: perks, decoration: InputDecoration(labelText: 'Perks')),
                TextField(controller: salary, decoration: InputDecoration(labelText: 'Salary')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                DatabaseHelper.instance.updateEmployee({
                  'sr': row['sr']!,
                  'name': name.text,
                  'designation': desig.text,
                  'joining_date': date.text,
                  'gross_salary': gross.text,
                  'perks': perks.text,
                  'salary': salary.text,
                });
                Navigator.pop(context);
                loadFromDatabase();
              },
              child: Text("Update"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Import Excel to DataTable')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: pickAndReadExcel3,
                  child: Text("Import Excel"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => exportToExcel(rows, columns),
                  child: Text("Export to Excel"),
                ),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: skipFirstRow,
                  onChanged: (value) {
                    setState(() {
                      skipFirstRow = value ?? true;
                    });
                  },
                ),
                const Text("Skip first row (header)"),
              ],
            ),

            SizedBox(height: 10),
            TextField(
              controller: searchController,
              decoration: InputDecoration(labelText: "Search"),
              onChanged: (value) {
                setState(() => searchTerm = value.toLowerCase());
              },
            ),
            SizedBox(height: 20),
            Expanded(
                child: columns.isNotEmpty
                    ? StyledDataTable(columns: columns, rows: rows)
                // child: DataTable(
                //   columns: columns,
                //   rows: rows.where((row) {
                //     return row.cells.any((cell) {
                //       final text = (cell.child as Text).data?.toLowerCase() ?? '';
                //       return text.contains(searchTerm);
                //     });
                //   }).toList(),
                // ),
                    : Center(child: Text('No data loaded')
                )),
          ],
        ),
      ),
    );
  }
}

class StyledDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const StyledDataTable({required this.columns, required this.rows, super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 5,
        ),
      ),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
            dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                return Colors.white;
              },
            ),
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
              fontSize: 16,
            ),
            dataTextStyle: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            dividerThickness: 0.7,
            columnSpacing: 30,
            columns: columns,
            rows: rows
                .asMap()
                .entries
                .map((entry) {
              int index = entry.key;
              DataRow row = entry.value;

              return DataRow(
                color: WidgetStateProperty.all(
                  index % 2 == 0 ? Colors.grey.shade100 : Colors.white,
                ),
                cells: row.cells.map((cell) {
                  return DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Builder(
                          builder: (context) {
                            final child = cell.child;
                            if (child is Text) {
                              return Text(
                                child.data ?? '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                              );
                            } else if (child is Row) {
                              // Handle Row specially, like for action buttons
                              return child;
                            } else {
                              return const Text(''); // fallback
                            }
                          },
                        ),
                      )
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

