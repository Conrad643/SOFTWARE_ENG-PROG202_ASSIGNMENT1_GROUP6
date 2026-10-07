# FeeTrack

A console-based school fee management prototype written in Dart. FeeTrack lets students register and pay term fees, while the bursar and admin track balances, defaulters, and collection rates. All data is saved to local JSON files.

Fees are shown in Leones (Le) and the curriculum is modelled on the Sierra Leone JSS/SSS system.

## The problem
Private secondary schools often record fees by hand in a paper ledger. This makes balances, receipts and defaulter lists slow and error-prone. (This is an assumption based on typical practice, not a study of one named school.)

## Features

**Students**
- Sign up and complete a registration profile (student, guardian, class, stream, subjects)
- Make fee payments per term, with partial payments supported
- View balance and payment status
- View payment history and receipts

**Bursar**
- View all registered students with guardian details and enrolled subjects
- View payment records and balances per term
- Print or reprint receipts (by receipt number, or latest receipt for a student and term)
- Collect fee payments on behalf of a student
- List defaulters with guardian phone numbers
- View collection summary per class

**Admin**
- Process payments and inspect student balances
- View payment history, defaulters, collection summary, and all students

**General**
- Subject selection logic for JSS 1-2, JSS 3, and SSS 1-3 (Science, Arts, Commercial streams)
- Overpayment protection and automatic receipt numbering (`RCP-0001`, ...)
- JSON persistence between runs

## Requirements

- [Dart SDK](https://dart.dev/get-dart) 2.17 or newer (uses `Enum.name`)

## Running

```bash
dart run feetracker.dart
```

## Default Accounts

| Role   | Username | Password   |
|--------|----------|------------|
| Admin  | `admin`  | `admin123` |
| Bursar | `Bursar` | `863001`   |

Students create their own accounts through **Sign Up**. The `Bursar` account is reset to the credentials above every time the program starts, and the username `bursar` is reserved. Change the default credentials in `loadDataFromDisk()` before using this anywhere real.

## Fee Schedule

| Class        | Term 1  | Term 2  | Term 3  |
|--------------|---------|---------|---------|
| JSS 1-3      | Le 1200 | Le 1000 | Le 800  |
| SSS 1-3      | Le 1800 | Le 1500 | Le 1200 |

Edit `initializeData()` to change these amounts.

## Data Storage

Data is written to the working directory as:

- `users.json`
- `guardians.json`
- `students.json`
- `payments.json`

Delete these files to reset the system. Classes and fee structures are defined in code and are not saved.

## Project Structure

Everything lives in a single file, `feetracker.dart`, organised into sections:

1. Enums and models with JSON serialization
2. Data storage and file persistence
3. Input helpers and validation
4. General helper functions
5. Curriculum subject logic
6. Initialization and fee schedule
7. Authentication
8. Registration
9. Payments and receipts
10. Bursar and admin dashboards
11. Menu and main loop

## Known Limitations

This is a prototype, not production software.

- Passwords are stored in plain text
- No payment reversal or editing
- Fee amounts can only be changed in code
- The admin menu does not include receipt reprinting (bursar only)
- Single-user, local files only, with no concurrency handling

## Possible Next Steps

- Hash passwords
- Add a database (SQLite) in place of JSON files
- Add SMS or mobile money integration for guardians
- Export reports to CSV or PDF
- Split the code into multiple files and add tests

## License

Released under the [MIT License](LICENSE).
