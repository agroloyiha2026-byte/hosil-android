/// O'zbekiston hududlari. Bazada o'zbekcha nom saqlanadi (filtrlar bir xil ishlashi uchun), ko'rsatishda tarjima qilinadi.
const regionsUz = [
  'Toshkent shahri', 'Toshkent viloyati', 'Andijon', 'Buxoro', "Farg'ona", 'Jizzax', 'Xorazm', 'Namangan', 'Navoiy',
  'Qashqadaryo', "Qoraqalpog'iston", 'Samarqand', 'Sirdaryo', 'Surxondaryo',
];

const _names = {
  'Toshkent shahri': ('Ташкент (город)', 'Tashkent city'), 'Toshkent viloyati': ('Ташкентская область', 'Tashkent region'),
  'Andijon': ('Андижан', 'Andijan'), 'Buxoro': ('Бухара', 'Bukhara'), "Farg'ona": ('Фергана', 'Fergana'), 'Jizzax': ('Джизак', 'Jizzakh'),
  'Xorazm': ('Хорезм', 'Khorezm'), 'Namangan': ('Наманган', 'Namangan'), 'Navoiy': ('Навои', 'Navoi'), 'Qashqadaryo': ('Кашкадарья', 'Kashkadarya'),
  "Qoraqalpog'iston": ('Каракалпакстан', 'Karakalpakstan'), 'Samarqand': ('Самарканд', 'Samarkand'), 'Sirdaryo': ('Сырдарья', 'Syrdarya'),
  'Surxondaryo': ('Сурхандарья', 'Surkhandarya'),
};

String regionLabel(String value, String lang) {
  final n = _names[value];
  if (n == null) return value;
  return lang == 'ru' ? n.$1 : lang == 'en' ? n.$2 : value;
}
