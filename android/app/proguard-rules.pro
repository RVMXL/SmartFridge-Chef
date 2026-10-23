# Дополнительные правила R8 — «Умный Холодильник & Шеф-Планер».
#
# google_mlkit_text_recognition в коде инициализации ссылается на классы
# распознавателей китайского, японского, корейского и деванагари,
# которые не входят в приложение (используется только latin-модель,
# com.google.mlkit:text-recognition). Без правил R8 падает с
# "Missing classes detected". -dontwarn только убирает ошибку
# линковки недостающих классов — поведение приложения не меняется.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
