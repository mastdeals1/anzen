const XLSX = require('xlsx');
const fs = require('fs');

try {
  const workbook = XLSX.readFile('dec_sep.xlsx');
  const sheetName = workbook.SheetNames[0];
  const worksheet = workbook.Sheets[sheetName];

  // Convert to JSON with headers
  const data = XLSX.utils.sheet_to_json(worksheet);

  console.log(JSON.stringify(data, null, 2));
} catch (error) {
  console.error('Error:', error.message);
}
