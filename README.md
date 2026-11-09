# Liblo

**A privacy-first personal finance app for iOS, built with Flutter.**

Liblo helps you track income and expenses, plan recurring costs and understand where your money goes, while keeping all your data on your own device.

[**Download on the App Store**](https://apps.apple.com/us/app/liblo-personal-finance/id6805533628)


## Features

- **Transactions and categories**: log income and expenses, organize them by category, and see the monthly balance carried over from the previous month
- **Spending analysis**: interactive charts, tap a category to see the filtered transactions
- **Planning**: recurring expenses, planned expenses and annual deadlines
- **Receipt scanning**: photograph a receipt and let on-device OCR pre-fill amount, date and merchant
- **Bank statement import**: import transactions from PDF statements, with duplicate detection
- **iCloud sync**: keep your data aligned across your devices
- **Biometric security**: lock the app with Face ID / Touch ID
- **CSV export**: export all your data in one shareable file
- **Multi-currency display** and **dark mode**

## Privacy by design

All data is stored locally in an SQLite database on the device. Receipt scanning and statement parsing run entirely on-device: no financial data is sent to external servers or cloud AI services.


## Engineering notes

- Sync compares a small version file stored next to the database instead of opening the database itself, which avoids connection conflicts and makes recency checks robust.
- Statement parsing uses per-bank parsers, each tested against real statements, rather than sending documents to a cloud model.

## Getting started

```bash
git clone https://github.com/saveriocoleschi26/personal-finance.git
cd personal-finance
flutter pub get
flutter run
```

Requires the Flutter SDK. iOS builds require macOS and Xcode.

## Author

**Saverio Coleschi**: [LinkedIn](https://www.linkedin.com/in/saverio-coleschi-91039a44a/)

## License
All rights reserved.
