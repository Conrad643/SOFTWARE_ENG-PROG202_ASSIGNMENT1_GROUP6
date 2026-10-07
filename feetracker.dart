// FeeTrack: School Fee Management System (Console Prototype)
// Supports Bursar Dashboard, Student Registration & JSON Persistence.
// Run with: dart run main.dart

import 'dart:convert';
import 'dart:io';

// ======================================================
// 1. ENUMS AND MODELS WITH JSON SERIALIZATION
// ======================================================

enum Role { admin, bursar, student }

enum SSSStream { none, science, arts, commercial }

class UserAccount {
  final String username;
  final String password;
  final Role role;
  int? studentId;

  UserAccount(this.username, this.password, this.role, {this.studentId});

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'role': role.name,
        'studentId': studentId,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      json['username'] as String,
      json['password'] as String,
      Role.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => Role.student,
      ),
      studentId: json['studentId'] as int?,
    );
  }
}

class Guardian {
  final int id;
  final String name;
  final String phone;

  Guardian(this.id, this.name, this.phone);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
      };

  factory Guardian.fromJson(Map<String, dynamic> json) {
    return Guardian(
      json['id'] as int,
      json['name'] as String,
      json['phone'] as String,
    );
  }
}

class SchoolClass {
  final int id;
  final String name;

  SchoolClass(this.id, this.name);
}

class FeeStructure {
  final int classId;
  final int term;
  double amount;

  FeeStructure(this.classId, this.term, this.amount);
}

class Student {
  final int id;
  final String name;
  final int classId;
  final int guardianId;
  final SSSStream stream;
  final List<String> enrolledSubjects;

  Student(
    this.id,
    this.name,
    this.classId,
    this.guardianId,
    this.enrolledSubjects, {
    this.stream = SSSStream.none,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'classId': classId,
        'guardianId': guardianId,
        'stream': stream.name,
        'enrolledSubjects': enrolledSubjects,
      };

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      json['id'] as int,
      json['name'] as String,
      json['classId'] as int,
      json['guardianId'] as int,
      List<String>.from(json['enrolledSubjects'] as List),
      stream: SSSStream.values.firstWhere(
        (s) => s.name == json['stream'],
        orElse: () => SSSStream.none,
      ),
    );
  }
}

class Payment {
  final String receiptNo;
  final int studentId;
  final int term;
  final double amount;
  final String method;
  final DateTime date;

  Payment(this.receiptNo, this.studentId, this.term, this.amount, this.method, this.date);

  Map<String, dynamic> toJson() => {
        'receiptNo': receiptNo,
        'studentId': studentId,
        'term': term,
        'amount': amount,
        'method': method,
        'date': date.toIso8601String(),
      };

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      json['receiptNo'] as String,
      json['studentId'] as int,
      json['term'] as int,
      (json['amount'] as num).toDouble(),
      json['method'] as String,
      DateTime.parse(json['date'] as String),
    );
  }
}

// ======================================================
// 2. DATA STORAGE & FILE PERSISTENCE
// ======================================================

List<UserAccount> users = [];
List<Guardian> guardians = [];
List<SchoolClass> classes = [];
List<FeeStructure> fees = [];
List<Student> students = [];
List<Payment> payments = [];

UserAccount? currentUser;

int nextStudentId = 1;
int nextGuardianId = 1;
int nextReceiptNo = 1;

void loadDataFromDisk() {
  try {
    File usersFile = File('users.json');
    if (usersFile.existsSync()) {
      String contents = usersFile.readAsStringSync();
      if (contents.trim().isNotEmpty) {
        List<dynamic> jsonList = jsonDecode(contents);
        users = jsonList.map((j) => UserAccount.fromJson(j)).toList();
      }
    }

    File guardiansFile = File('guardians.json');
    if (guardiansFile.existsSync()) {
      String contents = guardiansFile.readAsStringSync();
      if (contents.trim().isNotEmpty) {
        List<dynamic> jsonList = jsonDecode(contents);
        guardians = jsonList.map((j) => Guardian.fromJson(j)).toList();
        for (var g in guardians) {
          if (g.id >= nextGuardianId) nextGuardianId = g.id + 1;
        }
      }
    }

    File studentsFile = File('students.json');
    if (studentsFile.existsSync()) {
      String contents = studentsFile.readAsStringSync();
      if (contents.trim().isNotEmpty) {
        List<dynamic> jsonList = jsonDecode(contents);
        students = jsonList.map((j) => Student.fromJson(j)).toList();
        for (var s in students) {
          if (s.id >= nextStudentId) nextStudentId = s.id + 1;
        }
      }
    }

    File paymentsFile = File('payments.json');
    if (paymentsFile.existsSync()) {
      String contents = paymentsFile.readAsStringSync();
      if (contents.trim().isNotEmpty) {
        List<dynamic> jsonList = jsonDecode(contents);
        payments = jsonList.map((j) => Payment.fromJson(j)).toList();
        for (var p in payments) {
          int? numPart = int.tryParse(p.receiptNo.replaceAll('RCP-', ''));
          if (numPart != null && numPart >= nextReceiptNo) {
            nextReceiptNo = numPart + 1;
          }
        }
      }
    }
  } catch (e) {
    print('Warning: Failed to load existing saved data ($e). Starting fresh.');
  }

  // Ensure Admin account exists
  if (!users.any((u) => u.username == 'admin')) {
    users.add(UserAccount('admin', 'admin123', Role.admin));
  }

  // Ensure fixed Bursar account exists
  if (!users.any((u) => u.username == 'Bursar')) {
    users.add(UserAccount('Bursar', '863001', Role.bursar));
  } else {
    // Force correct password and role for the Bursar account if modified
    int idx = users.indexWhere((u) => u.username == 'Bursar');
    users[idx] = UserAccount('Bursar', '863001', Role.bursar);
  }

  saveDataToDisk();
}

void saveDataToDisk() {
  try {
    File('users.json').writeAsStringSync(
      jsonEncode(users.map((u) => u.toJson()).toList()),
    );
    File('guardians.json').writeAsStringSync(
      jsonEncode(guardians.map((g) => g.toJson()).toList()),
    );
    File('students.json').writeAsStringSync(
      jsonEncode(students.map((s) => s.toJson()).toList()),
    );
    File('payments.json').writeAsStringSync(
      jsonEncode(payments.map((p) => p.toJson()).toList()),
    );
  } catch (e) {
    print('Error saving data to disk: $e');
  }
}

// ======================================================
// 3. INPUT HELPERS
// ======================================================

String readText(String prompt) {
  stdout.write(prompt);
  String? line = stdin.readLineSync();
  if (line == null) {
    print('\nInput ended. Closing the program.');
    exit(0);
  }
  return line.trim();
}

int readInt(String prompt, int min, int max) {
  while (true) {
    String input = readText(prompt);
    int? value = int.tryParse(input);
    if (value == null) {
      print('Invalid input. Please enter a number.');
    } else if (value < min || value > max) {
      print('Please enter a number between $min and $max.');
    } else {
      return value;
    }
  }
}

double readAmount(String prompt) {
  while (true) {
    String input = readText(prompt).replaceAll(',', '');
    double? value = double.tryParse(input);
    if (value == null) {
      print('Invalid amount. Please enter a valid number.');
    } else if (value <= 0) {
      print('The amount must be greater than zero.');
    } else {
      return roundMoney(value);
    }
  }
}

String readName(String prompt) {
  RegExp pattern = RegExp(r"^[A-Za-z .'-]{2,}$");
  while (true) {
    String input = readText(prompt);
    if (pattern.hasMatch(input)) {
      return input;
    }
    print('Invalid name. Use letters only (at least 2 characters).');
  }
}

String readPhone(String prompt) {
  RegExp pattern = RegExp(r'^[0-9]{8,11}$');
  while (true) {
    String input = readText(prompt);
    if (pattern.hasMatch(input)) {
      return input;
    }
    print('Invalid phone number. Enter 8 to 11 digits only.');
  }
}

String chooseMethod() {
  print('\nSelect Payment Channel:');
  print('  1) Cash');
  print('  2) Bank Transfer');
  print('  3) Mobile Money');
  int choice = readInt('Choose method (1-3): ', 1, 3);
  if (choice == 1) return 'Cash';
  if (choice == 2) return 'Bank Transfer';
  return 'Mobile Money';
}

String promptLanguageSelection() {
  print('\nSelect specific Introductory / Local Language:');
  print('  1) Temne');
  print('  2) Limba');
  print('  3) Mende');
  print('  4) Krio');
  print('  5) French');
  print('  6) Arabic');
  
  int choice = readInt('Choose language (1-6): ', 1, 6);
  List<String> languages = ['Temne', 'Limba', 'Mende', 'Krio', 'French', 'Arabic'];
  return 'Local Language (${languages[choice - 1]})';
}

// ======================================================
// 4. HELPER FUNCTIONS
// ======================================================

double roundMoney(double value) {
  return double.parse(value.toStringAsFixed(2));
}

String money(double value) {
  return 'Le ${value.toStringAsFixed(2)}';
}

String formatDate(DateTime d) {
  String month = d.month.toString().padLeft(2, '0');
  String day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$month-$day';
}

Student? findStudent(int id) {
  for (Student s in students) {
    if (s.id == id) return s;
  }
  return null;
}

Guardian? findGuardian(int id) {
  for (Guardian g in guardians) {
    if (g.id == id) return g;
  }
  return null;
}

String className(int classId) {
  for (SchoolClass c in classes) {
    if (c.id == classId) return c.name;
  }
  return 'Unknown';
}

FeeStructure? getFee(int classId, int term) {
  for (FeeStructure f in fees) {
    if (f.classId == classId && f.term == term) return f;
  }
  return null;
}

double totalPaid(int studentId, int term) {
  double total = 0;
  for (Payment p in payments) {
    if (p.studentId == studentId && p.term == term) {
      total += p.amount;
    }
  }
  return roundMoney(total);
}

Payment addPayment(int studentId, int term, double amount, String method) {
  String receiptNo = 'RCP-${nextReceiptNo.toString().padLeft(4, '0')}';
  nextReceiptNo++;
  Payment p = Payment(receiptNo, studentId, term, amount, method, DateTime.now());
  payments.add(p);
  saveDataToDisk();
  return p;
}

void printLine() {
  print('-' * 65);
}

void pause() {
  readText('\nPress Enter to continue...');
}

// ======================================================
// 5. CURRICULUM SUBJECT LOGIC
// ======================================================

List<String> getJSS1And2Subjects() {
  String chosenLanguage = promptLanguageSelection();
  return [
    'Mathematics',
    'English Language',
    'Integrated Science',
    'Social Studies',
    chosenLanguage,
    'Religious and Moral Education (RME)',
    'Agriculture Science',
    'Physical and Health Education (PHE)',
    'Business Studies',
    'Home Economics',
    'Introductory Technology',
    'Basic Electricity',
    'Performing Arts',
    'Practical Arts'
  ];
}

List<String> configureJSS3Subjects() {
  List<String> selected = [
    'Mathematics',
    'English Language',
    'Integrated Science',
    'Social Studies'
  ];

  List<String> optionals = [
    'Introductory Language / Local Languages',
    'Religious and Moral Education (RME)',
    'Agriculture Science',
    'Physical and Health Education (PHE)',
    'Business Studies',
    'Home Economics',
    'Introductory Technology',
    'Basic Electricity',
    'Performing Arts',
    'Practical Arts'
  ];

  print('\n--- JSS 3 Subject Selection ---');
  print('Compulsory Core Subjects (4):');
  for (var s in selected) {
    print('  - $s');
  }

  print('\nSelect EXACTLY 4 Optional Subjects:');
  List<String> chosenOptionals = [];

  while (chosenOptionals.length < 4) {
    print('\nAvailable Optionals:');
    for (int i = 0; i < optionals.length; i++) {
      if (!chosenOptionals.contains(optionals[i])) {
        print('  ${i + 1}. ${optionals[i]}');
      }
    }

    int choice = readInt('Choose optional subject #${chosenOptionals.length + 1} (1-${optionals.length}): ', 1, optionals.length);
    
    if (choice == 1) {
      String specificLang = promptLanguageSelection();
      if (chosenOptionals.contains(specificLang)) {
        print('You have already chosen this language. Select a different optional subject.');
      } else {
        chosenOptionals.add(specificLang);
        print('Added: $specificLang');
      }
    } else {
      String picked = optionals[choice - 1];
      if (chosenOptionals.contains(picked)) {
        print('You have already chosen this subject. Select a different one.');
      } else {
        chosenOptionals.add(picked);
        print('Added: $picked');
      }
    }
  }

  selected.addAll(chosenOptionals);
  return selected;
}

List<String> configureSSSSubjects(int classId, SSSStream stream) {
  List<String> compulsory = ['English Language', 'General Mathematics'];
  List<String> coreStream = [];
  List<String> optionals = [];

  if (stream == SSSStream.science) {
    compulsory = ['English Language', 'Mathematics'];
    coreStream = ['Physics', 'Chemistry', 'Biology', 'Core Science'];
    optionals = ['Further Mathematics', 'Geography', 'Agricultural Science', 'Technical Drawing'];
  } else if (stream == SSSStream.arts) {
    coreStream = [
      'Christian Religious Studies (CRS)',
      'Islamic Studies',
      'Literature-in-English',
      'Government / Politics & Governance',
      'History'
    ];
    optionals = ['French', 'Arabic Language', 'Geography', 'Economics', 'Music', 'Visual Art'];
  } else if (stream == SSSStream.commercial) {
    coreStream = [
      'Principles of Business Management Studies',
      'Principles of Accounting',
      'Business Accounting',
      'Principles of Commerce',
      'Economics'
    ];
    optionals = ['Agricultural Science', 'Geography', 'Health Science', 'French', 'Further Mathematics'];
  }

  List<String> finalSubjects = [];
  finalSubjects.addAll(compulsory);
  finalSubjects.addAll(coreStream);

  if (classId == 6) {
    print('\n--- SSS 3 Stream Subject Selection ---');
    print('Default Compulsory & Stream Core (${finalSubjects.length}):');
    for (var sub in finalSubjects) {
      print('  - $sub');
    }

    int remainingNeeded = 7 - finalSubjects.length;
    List<String> selectedOptionals = [];

    if (remainingNeeded > 0) {
      print('\nSelect at least $remainingNeeded optional subject(s) to reach 7 subjects minimum.');

      while (finalSubjects.length + selectedOptionals.length < 7) {
        print('\nAvailable Elective Optionals:');
        for (int i = 0; i < optionals.length; i++) {
          if (!selectedOptionals.contains(optionals[i])) {
            print('  ${i + 1}. ${optionals[i]}');
          }
        }

        int choice = readInt('Select optional subject (1-${optionals.length}): ', 1, optionals.length);
        String picked = optionals[choice - 1];
        if (selectedOptionals.contains(picked)) {
          print('Subject already selected.');
        } else {
          selectedOptionals.add(picked);
          print('Added: $picked');
        }
      }
    }

    finalSubjects.addAll(selectedOptionals);

    while (finalSubjects.length < 9) {
      print('\nYou currently have ${finalSubjects.length} subjects selected.');
      print('  1) Add another optional subject (Max 9)');
      print('  2) Finish subject selection');
      int addMoreChoice = readInt('Choose option (1-2): ', 1, 2);

      if (addMoreChoice == 2) break;

      List<String> available = optionals.where((o) => !finalSubjects.contains(o)).toList();
      if (available.isEmpty) {
        print('No more optional subjects available to pick.');
        break;
      }

      print('\nAvailable Elective Optionals:');
      for (int i = 0; i < available.length; i++) {
        print('  ${i + 1}. ${available[i]}');
      }

      int choice = readInt('Select extra optional subject (1-${available.length}): ', 1, available.length);
      String picked = available[choice - 1];
      finalSubjects.add(picked);
      print('Added: $picked');
    }
  } else {
    finalSubjects.addAll(optionals.take(2));
  }

  return finalSubjects;
}

// ======================================================
// 6. INITIALIZATION & FIXED FEE SCHEDULE
// ======================================================

void initializeData() {
  List<String> classNames = ['JSS 1', 'JSS 2', 'JSS 3', 'SSS 1', 'SSS 2', 'SSS 3'];
  for (int i = 0; i < classNames.length; i++) {
    classes.add(SchoolClass(i + 1, classNames[i]));
  }

  for (int classId = 1; classId <= 3; classId++) {
    fees.add(FeeStructure(classId, 1, 1200.0));
    fees.add(FeeStructure(classId, 2, 1000.0));
    fees.add(FeeStructure(classId, 3, 800.0));
  }

  for (int classId = 4; classId <= 6; classId++) {
    fees.add(FeeStructure(classId, 1, 1800.0));
    fees.add(FeeStructure(classId, 2, 1500.0));
    fees.add(FeeStructure(classId, 3, 1200.0));
  }

  loadDataFromDisk();
}

// ======================================================
// 7. AUTHENTICATION (Sign Up / Login)
// ======================================================

void userSignUp() {
  print('\n--- Student Sign Up ---');
  print(' (Enter "0" to return to Main Menu)');
  String username = readText('Enter new username: ');

  if (username == '0') {
    print('Returning to main menu...');
    return;
  }

  if (username.toLowerCase() == 'bursar') {
    print('\nNOTICE: "Bursar" is a reserved administrative account.');
    print('Please use option 2 (Login) and enter the Bursar credentials.');
    return;
  }

  for (UserAccount u in users) {
    if (u.username.toLowerCase() == username.toLowerCase()) {
      print('Error: Username already exists. Please login or select another username.');
      return;
    }
  }

  String password = readText('Enter password: ');

  UserAccount newAccount = UserAccount(username, password, Role.student);
  users.add(newAccount);
  currentUser = newAccount;
  saveDataToDisk();

  print('\nAccount created and saved successfully!');
  print('Logged in as: $username');
  print('Proceeding to complete Student Registration Profile...');

  registerStudent();
}

void userLogin() {
  print('\n--- User Login ---');
  print(' (Enter "0" to return to Main Menu)');
  String username = readText('Username: ');

  if (username == '0') {
    print('Returning to main menu...');
    return;
  }

  String password = readText('Password: ');

  for (UserAccount u in users) {
    if (u.username == username && u.password == password) {
      currentUser = u;
      print('\nLogin successful!');
      if (u.role == Role.bursar) {
        print('*** WELCOME BURSAR - FINANCIAL MANAGEMENT DASHBOARD ***');
      } else if (u.role == Role.admin) {
        print('*** WELCOME ADMINISTRATOR ***');
      } else {
        print('Welcome back, ${u.username}.');
      }
      return;
    }
  }
  print('\nError: Invalid credentials or account does not exist.');
  print('If you have not registered yet, please sign up first.');
}

// ======================================================
// 8. REGISTRATION & FEE DISPLAY
// ======================================================

void registerStudent() {
  if (currentUser == null) {
    print('Error: You must sign up or log in first.');
    return;
  }

  if (currentUser!.role == Role.student && currentUser!.studentId != null) {
    print('Error: Profile already completed for this account.');
    return;
  }

  print('\n--- Student Registration Profile ---');
  String name = readName('Student full name: ');

  String guardianName = readName('Guardian full name: ');
  String phone = readPhone('Guardian phone number: ');

  print('\nAvailable Classes:');
  for (SchoolClass c in classes) {
    print('  ${c.id}. ${c.name}');
  }
  int classId = readInt('Choose class number (1-${classes.length}): ', 1, classes.length);

  SSSStream stream = SSSStream.none;
  List<String> chosenSubjects = [];

  if (classId >= 4) {
    print('\nSelect Academic Field / Stream for ${className(classId)}:');
    print('  1. Science');
    print('  2. Arts');
    print('  3. Commercial');
    int stChoice = readInt('Choose stream (1-3): ', 1, 3);
    if (stChoice == 1) stream = SSSStream.science;
    if (stChoice == 2) stream = SSSStream.arts;
    if (stChoice == 3) stream = SSSStream.commercial;
  }

  if (classId == 1 || classId == 2) {
    chosenSubjects = getJSS1And2Subjects();
  } else if (classId == 3) {
    chosenSubjects = configureJSS3Subjects();
  } else {
    chosenSubjects = configureSSSSubjects(classId, stream);
  }

  print('\n' + '=' * 65);
  print(' ACADEMIC SUBJECTS OFFERED - ${className(classId)}');
  print('=' * 65);
  for (int i = 0; i < chosenSubjects.length; i++) {
    print('  ${i + 1}. ${chosenSubjects[i]}');
  }

  printLine();
  print(' CLASS FIXED FEE SCHEDULE (${className(classId)})');
  printLine();
  for (int term = 1; term <= 3; term++) {
    FeeStructure? fee = getFee(classId, term);
    print('  Term $term Fee: ${money(fee?.amount ?? 0.0)}');
  }
  print('=' * 65);

  Guardian guardian = Guardian(nextGuardianId++, guardianName, phone);
  guardians.add(guardian);

  Student student = Student(
    nextStudentId++,
    name,
    classId,
    guardian.id,
    chosenSubjects,
    stream: stream,
  );
  students.add(student);

  if (currentUser!.role == Role.student) {
    currentUser!.studentId = student.id;
  }

  saveDataToDisk();

  print('\nRegistration Completed & Saved Successfully!');
  print('Assigned Student ID: ${student.id} | Class: ${className(classId)}');
}

// ======================================================
// 9. FINANCIAL TRANSACTIONS & PAYMENT MANAGEMENT
// ======================================================

void makePayment() {
  if (currentUser == null) {
    print('Error: Please log in first.');
    return;
  }

  int? sId = currentUser!.studentId;
  if (currentUser!.role == Role.admin || currentUser!.role == Role.bursar) {
    sId = readInt('Enter Student ID to process payment: ', 1, 999999);
  }

  if (sId == null) {
    print('Error: No registered student profile attached to this account.');
    return;
  }

  Student? student = findStudent(sId);
  if (student == null) {
    print('Error: Student record not found.');
    return;
  }

  print('\n--- Make Term Fee Payment ---');
  print(' (Enter 0 to go Back)');
  int term = readInt('Enter Term / Semester (1-3, 0 to Back): ', 0, 3);
  if (term == 0) return;

  FeeStructure? feeStruct = getFee(student.classId, term);
  if (feeStruct == null) {
    print('Error: No fee set for ${className(student.classId)} in Term $term.');
    return;
  }

  double fixedFee = feeStruct.amount;
  double paidSoFar = totalPaid(student.id, term);
  double balance = roundMoney(fixedFee - paidSoFar);

  print('\n' + '=' * 65);
  print(' PAYMENT OBLIGATION STATEMENT - TERM $term');
  print('=' * 65);
  print('Student Name   : ${student.name} (ID: ${student.id})');
  print('Class          : ${className(student.classId)}');
  print('Fixed Term Fee : ${money(fixedFee)}');
  print('Amount Paid    : ${money(paidSoFar)}');
  print('Current Balance: ${money(balance)}');

  if (balance <= 0) {
    print('\nSTATUS: PAYMENT COMPLETED IN FULL! No outstanding fee for Term $term.');
    print('=' * 65);
    return;
  } else {
    print('STATUS: OUTSTANDING BALANCE REMAINING');
  }
  print('=' * 65);

  print('\nEnter Payment Details:');
  double paymentAmount = readAmount('Enter amount to pay: ');

  if (paymentAmount > balance) {
    print('Error: Payment exceeds current outstanding balance of ${money(balance)}.');
    return;
  }

  String paymentMethod = chooseMethod();
  Payment payment = addPayment(student.id, term, paymentAmount, paymentMethod);

  double updatedBalance = roundMoney(balance - paymentAmount);

  printReceipt(payment, student, updatedBalance);
}

void printReceipt(Payment p, Student student, double balanceAfter) {
  print('');
  print('=' * 65);
  print('                 OFFICIAL FEETRACK RECEIPT');
  print('=' * 65);
  print('Receipt No    : ${p.receiptNo}');
  print('Date          : ${formatDate(p.date)}');
  print('Student Name  : ${student.name} (ID: ${student.id})');
  print('Class         : ${className(student.classId)}');
  print('Term          : ${p.term}');
  print('Method        : ${p.method}');
  print('Amount Paid   : ${money(p.amount)}');
  printLine();
  if (balanceAfter <= 0) {
    print('FINAL BALANCE : ${money(0.00)} [ FEES COMPLETED IN FULL ]');
  } else {
    print('FINAL BALANCE : ${money(balanceAfter)} [ PARTIAL PAYMENT ]');
  }
  print('=' * 65);
}

void viewMyBalance() {
  if (currentUser == null) {
    print('Error: Please log in first.');
    return;
  }

  int? sId = currentUser!.studentId;
  if (currentUser!.role == Role.admin || currentUser!.role == Role.bursar) {
    sId = readInt('Enter Student ID to inspect: ', 1, 999999);
  }

  if (sId == null) {
    print('Error: No student profile registered yet.');
    return;
  }

  Student? student = findStudent(sId);
  if (student == null) {
    print('Error: Student profile missing.');
    return;
  }

  print('\n--- View Balance & Status ---');
  print(' (Enter 0 to go Back)');
  int term = readInt('Enter term (1-3, 0 to Back): ', 0, 3);
  if (term == 0) return;

  FeeStructure? feeStruct = getFee(student.classId, term);
  if (feeStruct == null) {
    print('No fee set for ${className(student.classId)} in Term $term.');
    return;
  }

  double fixedFee = feeStruct.amount;
  double paid = totalPaid(student.id, term);
  double balance = roundMoney(fixedFee - paid);

  String status = (balance <= 0)
      ? 'COMPLETED IN FULL'
      : (paid > 0 ? 'PARTIAL PAYMENT' : 'NOT PAID');

  printLine();
  print('STUDENT BALANCE SUMMARY');
  printLine();
  print('Student Name  : ${student.name} (${className(student.classId)})');
  print('Term / Semester: $term');
  print('Fixed Term Fee: ${money(fixedFee)}');
  print('Total Paid    : ${money(paid)}');
  print('Balance Owed  : ${money(balance)}');
  print('Payment Status: $status');
  printLine();
}

void viewMyPaymentHistory() {
  if (currentUser == null) {
    print('Error: Please log in first.');
    return;
  }

  int? sId = currentUser!.studentId;
  if (currentUser!.role == Role.admin || currentUser!.role == Role.bursar) {
    sId = readInt('Enter Student ID to inspect: ', 1, 999999);
  }

  if (sId == null) {
    print('Error: No student profile linked.');
    return;
  }

  Student? student = findStudent(sId);
  if (student == null) {
    print('Error: Student record missing.');
    return;
  }

  print('\nPayment History for ${student.name} (${className(student.classId)})');
  printLine();

  int count = 0;
  double total = 0;
  for (Payment p in payments) {
    if (p.studentId == student.id) {
      count++;
      total += p.amount;
      print('${p.receiptNo}  ${formatDate(p.date)}  Term ${p.term}  ${money(p.amount)}  ${p.method}');
    }
  }

  if (count == 0) {
    print('No payment records found.');
  } else {
    printLine();
    print('Total Transactions: $count | Aggregate Paid: ${money(roundMoney(total))}');
  }
}

// ======================================================
// 10. BURSAR & ADMIN DASHBOARD FEATURES
// ======================================================

void bursarViewAllStudents() {
  print('\n=====================================================');
  print(' BURSAR REGISTERED STUDENTS DIRECTORY');
  print('=====================================================');
  if (students.isEmpty) {
    print('No students have registered in the system yet.');
    return;
  }

  for (Student s in students) {
    Guardian? g = findGuardian(s.guardianId);
    String guardianInfo = (g == null) ? 'N/A' : '${g.name} (${g.phone})';
    String streamStr = (s.stream != SSSStream.none) ? ' | Stream: ${s.stream.name.toUpperCase()}' : '';

    print('ID: ${s.id.toString().padRight(4)} | Name: ${s.name.padRight(20)} | Class: ${className(s.classId)}$streamStr');
    print('     Guardian: $guardianInfo');
    print('     Enrolled Subjects (${s.enrolledSubjects.length}): ${s.enrolledSubjects.join(', ')}');
    printLine();
  }
  print('Total Registered Students: ${students.length}');
}

void bursarViewPaymentRecordsAndBalances() {
  print('\n=====================================================');
  print(' BURSAR PAYMENT RECORDS & BALANCE LEDGER');
  print('=====================================================');
  print(' (Enter 0 to go Back)');
  int term = readInt('Enter Term to Inspect (1-3, 0 to Back): ', 0, 3);
  if (term == 0) return;

  if (students.isEmpty) {
    print('No students registered.');
    return;
  }

  printLine();
  print('${'ID'.padRight(5)}${'Student Name'.padRight(20)}${'Class'.padRight(8)}${'Required'.padRight(12)}${'Paid'.padRight(12)}Balance');
  printLine();

  double grandRequired = 0;
  double grandPaid = 0;
  double grandBalance = 0;

  for (Student s in students) {
    FeeStructure? feeStruct = getFee(s.classId, term);
    double requiredFee = feeStruct?.amount ?? 0.0;
    double paid = totalPaid(s.id, term);
    double balance = roundMoney(requiredFee - paid);

    grandRequired += requiredFee;
    grandPaid += paid;
    grandBalance += balance;

    print('${s.id.toString().padRight(5)}'
        '${s.name.padRight(20)}'
        '${className(s.classId).padRight(8)}'
        '${money(requiredFee).padRight(12)}'
        '${money(paid).padRight(12)}'
        '${money(balance)}');
  }

  printLine();
  print('SUMMARY FOR TERM $term:');
  print(' Total Expected Fees : ${money(roundMoney(grandRequired))}');
  print(' Total Collected     : ${money(roundMoney(grandPaid))}');
  print(' Total Outstanding   : ${money(roundMoney(grandBalance))}');
  printLine();
}

void bursarReprintReceipt() {
  print('\n--- BURSAR RECEIPT REPRINT SERVICE ---');
  print(' 1. Search & Reprint by Receipt Number');
  print(' 2. Select Student & Term to Reprint Latest Receipt');
  print(' 0. Back');

  int choice = readInt('Choose option (0-2): ', 0, 2);
  if (choice == 0) return;

  if (choice == 1) {
    String rcNo = readText('Enter Receipt Number (e.g., RCP-0001): ');
    Payment? targetPayment;
    for (Payment p in payments) {
      if (p.receiptNo.toLowerCase() == rcNo.toLowerCase()) {
        targetPayment = p;
        break;
      }
    }

    if (targetPayment == null) {
      print('Error: Receipt "$rcNo" not found in payment system.');
      return;
    }

    Student? student = findStudent(targetPayment.studentId);
    if (student == null) {
      print('Error: Associated student profile missing.');
      return;
    }

    FeeStructure? feeStruct = getFee(student.classId, targetPayment.term);
    double fixedFee = feeStruct?.amount ?? 0.0;
    double paidSoFar = totalPaid(student.id, targetPayment.term);
    double balance = roundMoney(fixedFee - paidSoFar);

    printReceipt(targetPayment, student, balance);
  } else if (choice == 2) {
    int sId = readInt('Enter Student ID: ', 1, 999999);
    Student? student = findStudent(sId);
    if (student == null) {
      print('Error: Student not found.');
      return;
    }

    int term = readInt('Enter Term (1-3): ', 1, 3);
    List<Payment> studentPayments = payments
        .where((p) => p.studentId == sId && p.term == term)
        .toList();

    if (studentPayments.isEmpty) {
      print('No payment records found for ${student.name} in Term $term.');
      return;
    }

    Payment lastPayment = studentPayments.last;
    FeeStructure? feeStruct = getFee(student.classId, term);
    double fixedFee = feeStruct?.amount ?? 0.0;
    double paidSoFar = totalPaid(student.id, term);
    double balance = roundMoney(fixedFee - paidSoFar);

    printReceipt(lastPayment, student, balance);
  }
}

void listDefaulters() {
  print('\n--- Defaulter List ---');
  print(' (Enter 0 to go Back)');
  int term = readInt('Enter term (1-3, 0 to Back): ', 0, 3);
  if (term == 0) return;

  printLine();

  int count = 0;
  double totalOwed = 0;
  for (Student s in students) {
    FeeStructure? feeStruct = getFee(s.classId, term);
    if (feeStruct == null) continue;

    double balance = roundMoney(feeStruct.amount - totalPaid(s.id, term));

    if (balance > 0) {
      count++;
      totalOwed += balance;
      Guardian? g = findGuardian(s.guardianId);
      String phone = (g == null) ? 'N/A' : g.phone;
      print('ID ${s.id}  ${s.name.padRight(18)} ${className(s.classId).padRight(6)} '
          'Owes: ${money(balance)}  Tel: $phone');
    }
  }

  if (count == 0) {
    print('No defaulters found for term $term.');
  } else {
    printLine();
    print('Defaulters Count: $count | Total Outstanding Balance: ${money(roundMoney(totalOwed))}');
  }
}

void classSummary() {
  print('\n--- Collection Summary per Class ---');
  print(' (Enter 0 to go Back)');
  int term = readInt('Enter term (1-3, 0 to Back): ', 0, 3);
  if (term == 0) return;

  printLine();
  print('${'Class'.padRight(8)}${'Students'.padRight(10)}${'Expected'.padRight(14)}${'Collected'.padRight(14)}Rate');
  printLine();

  double grandExpected = 0;
  double grandCollected = 0;

  for (SchoolClass c in classes) {
    FeeStructure? feeStruct = getFee(c.id, term);
    if (feeStruct == null) {
      print('${c.name.padRight(8)}No fee set');
      continue;
    }

    int studentCount = 0;
    double collected = 0;

    for (Student s in students) {
      if (s.classId == c.id) {
        studentCount++;
        collected += totalPaid(s.id, term);
      }
    }

    double expected = feeStruct.amount * studentCount;
    double rate = (expected == 0) ? 0 : (collected / expected) * 100;
    grandExpected += expected;
    grandCollected += collected;

    print('${c.name.padRight(8)}${studentCount.toString().padRight(10)}'
        '${expected.toStringAsFixed(2).padRight(14)}'
        '${collected.toStringAsFixed(2).padRight(14)}'
        '${rate.toStringAsFixed(1)}%');
  }

  printLine();
  double overallRate = (grandExpected == 0) ? 0 : (grandCollected / grandExpected) * 100;
  print('Total Expected : ${money(roundMoney(grandExpected))}');
  print('Total Collected: ${money(roundMoney(grandCollected))}');
  print('Outstanding    : ${money(roundMoney(grandExpected - grandCollected))}');
  print('Collection Rate: ${overallRate.toStringAsFixed(1)}%');
}

void viewAllStudents() {
  print('\n--- All Registered Students ---');
  printLine();
  if (students.isEmpty) {
    print('No registered students.');
    return;
  }

  for (Student s in students) {
    Guardian? g = findGuardian(s.guardianId);
    String guardianName = (g == null) ? 'N/A' : g.name;
    print('ID ${s.id} | ${s.name.padRight(18)} | ${className(s.classId).padRight(6)} | Subjects: ${s.enrolledSubjects.length} | Guardian: $guardianName');
  }
  printLine();
  print('Total Students: ${students.length}');
}

// ======================================================
// 11. MAIN ROUTER AND INTERFACE
// ======================================================

void showMenu() {
  print('');
  print('=' * 65);
  print('      FEETRACK - SCHOOL FEE MANAGEMENT SYSTEM');
  print('=' * 65);
  if (currentUser == null) {
    print(' 1. Sign Up (New Student)');
    print(' 2. Login');
    print(' 0. Exit');
  } else if (currentUser!.role == Role.bursar) {
    print(' LOGGED IN AS: BURSAR (FINANCE DEPARTMENT)');
    print(' 1. View All Registered Students');
    print(' 2. View All Payment Records & Balances');
    print(' 3. Print / Reprint Receipts');
    print(' 4. Collect & Process Student Fee Payment');
    print(' 5. List Defaulters');
    print(' 6. Class Collection Summary');
    print(' 9. Logout');
    print(' 0. Exit');
  } else if (currentUser!.role == Role.student) {
    print(' LOGGED IN AS STUDENT: ${currentUser!.username}');
    print(' 1. Make Fee Payment');
    print(' 2. View My Balance & Status');
    print(' 3. View Payment Receipts & History');

    if (currentUser!.studentId == null) {
      print(' 4. Complete Student Profile Registration');
    }

    print(' 9. Logout');
    print(' 0. Exit');
  } else if (currentUser!.role == Role.admin) {
    print(' LOGGED IN AS ADMINISTRATOR: ${currentUser!.username}');
    print(' 1. Process Payment');
    print(' 2. Inspect Student Balance & Status');
    print(' 3. View Payment Receipts & History');
    print(' 4. List Defaulters');
    print(' 5. Collection Summary');
    print(' 6. View All Students');
    print(' 9. Logout');
    print(' 0. Exit');
  }
  print('-' * 65);
}

void main() {
  initializeData();

  bool running = true;
  while (running) {
    showMenu();

    if (currentUser == null) {
      int choice = readInt('Enter choice (0-2): ', 0, 2);
      switch (choice) {
        case 1:
          userSignUp();
          break;
        case 2:
          userLogin();
          break;
        case 0:
          running = false;
          break;
      }
    } else if (currentUser!.role == Role.bursar) {
      int choice = readInt('Enter Bursar Option: ', 0, 9);
      switch (choice) {
        case 1:
          bursarViewAllStudents();
          break;
        case 2:
          bursarViewPaymentRecordsAndBalances();
          break;
        case 3:
          bursarReprintReceipt();
          break;
        case 4:
          makePayment();
          break;
        case 5:
          listDefaulters();
          break;
        case 6:
          classSummary();
          break;
        case 9:
          currentUser = null;
          print('\nLogged out successfully.');
          break;
        case 0:
          running = false;
          break;
        default:
          print('Invalid selection.');
      }
    } else if (currentUser!.role == Role.student) {
      int choice = readInt('Enter Student Option: ', 0, 9);
      switch (choice) {
        case 1:
          makePayment();
          break;
        case 2:
          viewMyBalance();
          break;
        case 3:
          viewMyPaymentHistory();
          break;
        case 4:
          registerStudent();
          break;
        case 9:
          currentUser = null;
          print('\nLogged out successfully.');
          break;
        case 0:
          running = false;
          break;
        default:
          print('Invalid selection.');
      }
    } else if (currentUser!.role == Role.admin) {
      int choice = readInt('Enter Admin Option: ', 0, 9);
      switch (choice) {
        case 1:
          makePayment();
          break;
        case 2:
          viewMyBalance();
          break;
        case 3:
          viewMyPaymentHistory();
          break;
        case 4:
          listDefaulters();
          break;
        case 5:
          classSummary();
          break;
        case 6:
          viewAllStudents();
          break;
        case 9:
          currentUser = null;
          print('\nLogged out successfully.');
          break;
        case 0:
          running = false;
          break;
        default:
          print('Invalid selection.');
      }
    }

    if (running) {
      pause();
    }
  }
  print('\nThank you for using FeeTrack. Goodbye!');
} 