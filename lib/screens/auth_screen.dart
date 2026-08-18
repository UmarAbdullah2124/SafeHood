import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_colors.dart';
import 'sign_in_screen.dart';
import 'safety_home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0;
  bool _isLoading = false;

  // Controllers
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final dobController = TextEditingController();
  final cnicController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final List<TextEditingController> otpControllers = List.generate(6, (i) => TextEditingController());

  // Error States
  String? firstNameError, lastNameError, emailError, dobError, cnicError, phoneError, passwordError, otpError;

  bool isLeftThumbCaptured = false;
  bool isRightThumbCaptured = false;

  // Focus nodes for auto-scrolling
  final FocusNode firstNameFocus = FocusNode();
  final FocusNode lastNameFocus = FocusNode();
  final FocusNode emailFocus = FocusNode();
  final FocusNode dobFocus = FocusNode();
  final FocusNode cnicFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _addFocusListeners();
  }

  void _addFocusListeners() {
    firstNameFocus.addListener(() {
      if (firstNameFocus.hasFocus) _scrollToPosition(0);
    });
    lastNameFocus.addListener(() {
      if (lastNameFocus.hasFocus) _scrollToPosition(80);
    });
    emailFocus.addListener(() {
      if (emailFocus.hasFocus) _scrollToPosition(160);
    });
    dobFocus.addListener(() {
      if (dobFocus.hasFocus) _scrollToPosition(240);
    });
    cnicFocus.addListener(() {
      if (cnicFocus.hasFocus) _scrollToPosition(320);
    });
    phoneFocus.addListener(() {
      if (phoneFocus.hasFocus) _scrollToPosition(400);
    });
    passwordFocus.addListener(() {
      if (passwordFocus.hasFocus) _scrollToPosition(480);
    });
  }

  void _scrollToPosition(double position) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    dobController.dispose();
    cnicController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    firstNameFocus.dispose();
    lastNameFocus.dispose();
    emailFocus.dispose();
    dobFocus.dispose();
    cnicFocus.dispose();
    phoneFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  // --- Navigation Methods ---
  void next() {
    if (_currentIndex == 0) {
      _validateRegistrationFormAndProceed();
    } else if (_currentIndex == 1) {
      if (_validateOTP()) {
        setState(() {
          _currentIndex++;
        });
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _registerUser();
    }
  }

  void previous() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- Validate Registration Form and Proceed Forward ---
  Future<void> _validateRegistrationFormAndProceed() async {
    bool isValid = true;

    if (firstNameController.text.trim().isEmpty) {
      setState(() => firstNameError = "First name is required");
      isValid = false;
    } else {
      setState(() => firstNameError = null);
    }

    if (lastNameController.text.trim().isEmpty) {
      setState(() => lastNameError = "Last name is required");
      isValid = false;
    } else {
      setState(() => lastNameError = null);
    }

    String email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() => emailError = "Email is required");
      isValid = false;
    } else if (!email.contains("@") || !email.contains(".")) {
      setState(() => emailError = "Enter a valid email address");
      isValid = false;
    } else {
      setState(() => emailError = null);
    }

    String dobText = dobController.text.trim();
    if (dobText.isEmpty) {
      setState(() => dobError = "Date of birth is required");
      isValid = false;
    } else {
      List<String> dateParts = dobText.split('/');
      if (dateParts.length == 3) {
        int day = int.tryParse(dateParts[0]) ?? 0;
        int month = int.tryParse(dateParts[1]) ?? 0;
        int year = int.tryParse(dateParts[2]) ?? 0;

        DateTime birthDate = DateTime(year, month, day);
        DateTime today = DateTime.now();
        int age = today.year - birthDate.year;

        if (today.month < birthDate.month ||
            (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }

        if (age < 18) {
          setState(() => dobError = "You must be at least 18 years old");
          isValid = false;
        } else {
          setState(() => dobError = null);
        }
      } else {
        setState(() => dobError = "Invalid date format");
        isValid = false;
      }
    }

    String cnic = cnicController.text.trim();
    if (cnic.isEmpty) {
      setState(() => cnicError = "CNIC is required");
      isValid = false;
    } else if (cnic.length < 13) {
      setState(() => cnicError = "Enter a valid CNIC (13 digits)");
      isValid = false;
    } else {
      setState(() => cnicError = null);
    }

    String phone = phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => phoneError = "Phone number is required");
      isValid = false;
    } else if (phone.length < 10) {
      setState(() => phoneError = "Enter a valid phone number");
      isValid = false;
    } else {
      setState(() => phoneError = null);
    }

    String password = passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => passwordError = "Password is required");
      isValid = false;
    } else if (password.length < 6) {
      setState(() => passwordError = "Password must be at least 6 characters");
      isValid = false;
    } else {
      setState(() => passwordError = null);
    }

    if (isValid) {
      setState(() => _isLoading = true);
      bool isCnicUnique = await _checkCnicUniqueness(cnic);
      setState(() => _isLoading = false);

      if (isCnicUnique) {
        setState(() {
          _currentIndex++;
        });
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() => cnicError = "This CNIC is already registered");
      }
    }
  }

  // --- Check if CNIC already exists in Firestore ---
  Future<bool> _checkCnicUniqueness(String cnic) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('cnic', isEqualTo: cnic)
          .limit(1)
          .get();

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      _showSnackBar("Error checking CNIC. Please try again.");
      return false;
    }
  }

  // --- Validate OTP ---
  bool _validateOTP() {
    bool allFieldsFilled = otpControllers.every((controller) => controller.text.length == 1);

    if (!allFieldsFilled) {
      setState(() => otpError = "Please enter complete OTP");
      return false;
    }

    setState(() => otpError = null);
    return true;
  }

  // --- The actual Firebase Save Logic ---
  Future<void> _registerUser() async {
    if (!isLeftThumbCaptured || !isRightThumbCaptured) {
      _showSnackBar("Please capture both thumbprints");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': emailController.text.trim(),
        'dob': dobController.text.trim(),
        'cnic': cnicController.text.trim(),
        'phone': phoneController.text.trim(),
        'uid': userCredential.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'biometricVerified': true,
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SafetyHomeScreen()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showSnackBar("Email already registered. Please use a different email.");
      } else {
        _showSnackBar(e.message ?? "Registration failed");
      }
    } catch (e) {
      _showSnackBar("Something went wrong. Check your internet connection.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _captureFingerprint(String side) async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 50,
      );

      if (photo != null) {
        setState(() {
          if (side == 'left') isLeftThumbCaptured = true;
          if (side == 'right') isRightThumbCaptured = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${side == 'left' ? 'Left' : 'Right'} thumb captured successfully!",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showSnackBar("Error opening camera: $e");
    }
  }

  // Real-time validation for better UX
  void validateFirstName(String v) {
    setState(() {
      if (v.isEmpty) firstNameError = "First name is required";
      else firstNameError = null;
    });
  }

  void validateLastName(String v) {
    setState(() {
      if (v.isEmpty) lastNameError = "Last name is required";
      else lastNameError = null;
    });
  }

  void validateEmail(String v) {
    setState(() {
      if (v.isEmpty) emailError = "Email is required";
      else if (!v.contains("@") || !v.contains(".")) emailError = "Enter a valid email address";
      else emailError = null;
    });
  }

  void validateDOB(String v) {
    setState(() {
      if (v.isEmpty) dobError = "Date of birth is required";
      else {
        List<String> dateParts = v.split('/');
        if (dateParts.length == 3) {
          int day = int.tryParse(dateParts[0]) ?? 0;
          int month = int.tryParse(dateParts[1]) ?? 0;
          int year = int.tryParse(dateParts[2]) ?? 0;

          if (year > 0 && month > 0 && day > 0) {
            DateTime birthDate = DateTime(year, month, day);
            DateTime today = DateTime.now();
            int age = today.year - birthDate.year;

            if (today.month < birthDate.month ||
                (today.month == birthDate.month && today.day < birthDate.day)) {
              age--;
            }

            if (age < 18) {
              dobError = "You must be at least 18 years old";
            } else {
              dobError = null;
            }
          } else {
            dobError = null;
          }
        } else {
          dobError = null;
        }
      }
    });
  }

  void validateCNIC(String v) {
    setState(() {
      if (v.isEmpty) cnicError = "CNIC is required";
      else if (v.length < 13) cnicError = "Enter a valid CNIC (13 digits)";
      else cnicError = null;
    });
  }

  void validatePhone(String v) {
    setState(() {
      if (v.isEmpty) phoneError = "Phone number is required";
      else if (v.length < 10) phoneError = "Enter a valid phone number";
      else phoneError = null;
    });
  }

  void validatePassword(String v) {
    setState(() {
      if (v.isEmpty) passwordError = "Password is required";
      else if (v.length < 6) passwordError = "Password must be at least 6 characters";
      else passwordError = null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 18 * 365)),
    );
    if (picked != null) {
      setState(() => dobController.text = "${picked.day}/${picked.month}/${picked.year}");
      validateDOB(dobController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 50),
              _progressBar(_currentIndex),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    RegisterUI(
                      onNext: next,
                      onPrevious: previous,
                      onSelectDate: () => _selectDate(context),
                      firstNameController: firstNameController,
                      lastNameController: lastNameController,
                      emailController: emailController,
                      dobController: dobController,
                      cnicController: cnicController,
                      phoneController: phoneController,
                      passwordController: passwordController,
                      firstNameError: firstNameError,
                      lastNameError: lastNameError,
                      emailError: emailError,
                      dobError: dobError,
                      cnicError: cnicError,
                      phoneError: phoneError,
                      passwordError: passwordError,
                      onFirstNameChanged: validateFirstName,
                      onLastNameChanged: validateLastName,
                      onEmailChanged: validateEmail,
                      onDOBChanged: validateDOB,
                      onCNICChanged: validateCNIC,
                      onPhoneChanged: validatePhone,
                      onPasswordChanged: validatePassword,
                      scrollController: _scrollController,
                      firstNameFocus: firstNameFocus,
                      lastNameFocus: lastNameFocus,
                      emailFocus: emailFocus,
                      dobFocus: dobFocus,
                      cnicFocus: cnicFocus,
                      phoneFocus: phoneFocus,
                      passwordFocus: passwordFocus,
                    ),
                    OTPUI(
                      onNext: next,
                      onPrevious: previous,
                      otpControllers: otpControllers,
                      otpError: otpError,
                    ),
                    FingerprintUI(
                      onNext: next,
                      onPrevious: previous,
                      onCaptureLeft: () => _captureFingerprint('left'),
                      onCaptureRight: () => _captureFingerprint('right'),
                      isLeftCaptured: isLeftThumbCaptured,
                      isRightCaptured: isRightThumbCaptured,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: AppColors.blue)),
            ),
        ],
      ),
    );
  }
}

Widget _progressBar(int index) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (i) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 90,
        height: 5,
        decoration: BoxDecoration(
          color: i <= index ? Colors.white : Colors.grey.shade700,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }),
  );
}

class Sheet extends StatelessWidget {
  final Widget child;
  const Sheet({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: child,
    );
  }
}

class RegisterUI extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSelectDate;
  final TextEditingController firstNameController, lastNameController, emailController, dobController, cnicController, phoneController, passwordController;
  final String? firstNameError, lastNameError, emailError, dobError, cnicError, phoneError, passwordError;
  final Function(String) onFirstNameChanged, onLastNameChanged, onEmailChanged, onDOBChanged, onCNICChanged, onPhoneChanged, onPasswordChanged;
  final ScrollController scrollController;
  final FocusNode firstNameFocus, lastNameFocus, emailFocus, dobFocus, cnicFocus, phoneFocus, passwordFocus;

  const RegisterUI({
    super.key,
    required this.onNext,
    required this.onPrevious,
    required this.onSelectDate,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.dobController,
    required this.cnicController,
    required this.phoneController,
    required this.passwordController,
    this.firstNameError,
    this.lastNameError,
    this.emailError,
    this.dobError,
    this.cnicError,
    this.phoneError,
    this.passwordError,
    required this.onFirstNameChanged,
    required this.onLastNameChanged,
    required this.onEmailChanged,
    required this.onDOBChanged,
    required this.onCNICChanged,
    required this.onPhoneChanged,
    required this.onPasswordChanged,
    required this.scrollController,
    required this.firstNameFocus,
    required this.lastNameFocus,
    required this.emailFocus,
    required this.dobFocus,
    required this.cnicFocus,
    required this.phoneFocus,
    required this.passwordFocus,
  });

  Widget inputField(String label, String hint, TextEditingController controller,
      {bool obscure = false, String? error, TextInputType? keyboardType,
        bool isReadOnly = false, VoidCallback? onTap, Function(String)? onChanged,
        FocusNode? focusNode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 13)),
            const Text(" *", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 13)),
            if (error != null) Expanded(child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 11), textAlign: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          readOnly: isReadOnly,
          onTap: onTap,
          onChanged: onChanged,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: isReadOnly ? const Icon(Icons.calendar_today, size: 18, color: Colors.grey) : null,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: error != null ? Colors.red : Colors.grey, width: error != null ? 1.5 : 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 0.8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Register", style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text("Already have an account? ", style: TextStyle(color: Colors.white70)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SignInScreen()),
                      );
                    },
                    child: const Text(
                      "Log In",
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Sheet(
            child: ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: inputField(
                        "First Name", "John", firstNameController,
                        error: firstNameError,
                        onChanged: onFirstNameChanged,
                        focusNode: firstNameFocus,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: inputField(
                        "Last Name", "Doe", lastNameController,
                        error: lastNameError,
                        onChanged: onLastNameChanged,
                        focusNode: lastNameFocus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                inputField(
                  "Email", "johndoe@gmail.com", emailController,
                  error: emailError,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: onEmailChanged,
                  focusNode: emailFocus,
                ),
                const SizedBox(height: 12),
                inputField(
                  "Date of Birth", "DD/MM/YYYY", dobController,
                  error: dobError,
                  isReadOnly: true,
                  onTap: onSelectDate,
                  onChanged: onDOBChanged,
                  focusNode: dobFocus,
                ),
                const SizedBox(height: 12),
                inputField(
                  "CNIC", "XXXXX-XXXXXXXX-X", cnicController,
                  error: cnicError,
                  onChanged: onCNICChanged,
                  keyboardType: TextInputType.number,
                  focusNode: cnicFocus,
                ),
                const SizedBox(height: 12),
                inputField(
                  "Phone Number", "03XXXXXXXXX", phoneController,
                  error: phoneError,
                  keyboardType: TextInputType.phone,
                  onChanged: onPhoneChanged,
                  focusNode: phoneFocus,
                ),
                const SizedBox(height: 12),
                inputField(
                  "Password", "********", passwordController,
                  obscure: true,
                  error: passwordError,
                  onChanged: onPasswordChanged,
                  focusNode: passwordFocus,
                ),
                const SizedBox(height: 25),
                _button("Send OTP", onNext),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OTPUI extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final List<TextEditingController> otpControllers;
  final String? otpError;

  const OTPUI({
    super.key,
    required this.onNext,
    required this.onPrevious,
    required this.otpControllers,
    this.otpError
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(child: Container(color: Colors.black, alignment: Alignment.center, child: SvgPicture.asset("lib/icons/otp.svg", height: 250))),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Sheet(
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text("OTP Verification", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkBg)),
                const SizedBox(height: 8),
                const Text("Enter the OTP sent to your phone", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(6, (i) => _buildOtpBox(i, context))),
                if (otpError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(otpError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                const Spacer(),
                _button("Verify", onNext, isEnabled: otpControllers.every((c) => c.text.length == 1)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index, BuildContext context) {
    return Container(
      width: 45,
      height: 65,
      child: TextField(
        controller: otpControllers[index],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: '*',
          hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.grey),
          contentPadding: EdgeInsets.only(bottom: 8),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) FocusScope.of(context).nextFocus();
          if (v.isEmpty && index > 0) FocusScope.of(context).previousFocus();
        },
      ),
    );
  }
}

class FingerprintUI extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onCaptureLeft;
  final VoidCallback onCaptureRight;
  final bool isLeftCaptured;
  final bool isRightCaptured;

  const FingerprintUI({
    super.key,
    required this.onNext,
    required this.onPrevious,
    required this.onCaptureLeft,
    required this.onCaptureRight,
    required this.isLeftCaptured,
    required this.isRightCaptured,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: SvgPicture.asset(
              "lib/icons/print.svg",
              height: 250,
            ),
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Sheet(
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Fingerprint Verification",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBg,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: FingerprintCaptureCard(
                        title: "Left Thumb",
                        isCaptured: isLeftCaptured,
                        onCapture: onCaptureLeft,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FingerprintCaptureCard(
                        title: "Right Thumb",
                        isCaptured: isRightCaptured,
                        onCapture: onCaptureRight,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _button(
                  "Complete Registration",
                  onNext,
                  isEnabled: isLeftCaptured && isRightCaptured,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FingerprintCaptureCard extends StatelessWidget {
  final String title;
  final bool isCaptured;
  final VoidCallback onCapture;

  const FingerprintCaptureCard({
    super.key,
    required this.title,
    required this.isCaptured,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCapture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isCaptured ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCaptured ? Colors.green : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCaptured
                    ? Colors.green.withOpacity(0.15)
                    : Colors.blue.withOpacity(0.10),
              ),
              child: Icon(
                isCaptured ? Icons.check_circle : Icons.fingerprint,
                size: 42,
                color: isCaptured ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCaptured ? "Captured" : "Tap to scan",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _button(String text, VoidCallback onTap, {bool isEnabled = true}) {
  return SizedBox(
    width: double.infinity,
    height: 55,
    child: ElevatedButton(
      onPressed: isEnabled ? onTap : null,
      style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppColors.blue : Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
      ),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
    ),
  );
}