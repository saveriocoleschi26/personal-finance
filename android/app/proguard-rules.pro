# Liblo usa solo il riconoscimento testo in caratteri latini
# (TextRecognitionScript.latin, per la scansione degli scontrini).
#
# google_mlkit_text_recognition supporta anche cinese, giapponese, coreano
# e devanagari, ma tramite pacchetti opzionali separati che non abbiamo
# incluso. Il codice del plugin li referenzia comunque in un'unica
# funzione di inizializzazione condivisa tra tutti gli script, quindi R8
# (l'ottimizzatore/minificatore del codice) li trova referenziati ma non
# trova le classi vere e proprie, e per sicurezza blocca la build invece
# di limitarsi ad avvisare.
#
# Queste righe dicono a R8 di ignorare l'assenza di quelle classi: è
# sicuro perché il nostro codice chiama sempre e solo l'inizializzazione
# con lo script latino.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
