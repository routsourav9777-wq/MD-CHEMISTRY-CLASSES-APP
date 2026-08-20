import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/chemistry_background.dart';
import '../../core/glass_card.dart';
import '../../core/theme.dart';
import '../auth/login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final SupabaseClient supabase = Supabase.instance.client;
  final FirebaseAuth auth = FirebaseAuth.instance;

  late final AnimationController introController;
  late final AnimationController atomController;

  int selectedPage = 0;

  String selectedStudentSemester = 'All';

  final List<String> studentSemesterOptions = const [
    'All',
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8',
  ];

  @override
  void initState() {
    super.initState();

    introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    atomController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    introController.dispose();
    atomController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    try {
      await auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Admin logout Firebase error: ${e.code}',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logout failed: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Admin logout error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to logout. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // STUDENT STATUS
  // ============================================================

  Future<void> updateStudentStatus(
    String uid,
    String status,
  ) async {
    try {
      await db.collection('users').doc(uid).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Student approved successfully.'
                : status == 'rejected'
                    ? 'Student rejected.'
                    : 'Student blocked.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SHIFT STUDENT SEMESTER
  // ============================================================

  Future<void> shiftStudentSemester(
    String uid,
    String currentSemester,
  ) async {
    final currentNumber = _semesterNumber(currentSemester);

    if (currentNumber == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Student semester is not recognized.',
          ),
        ),
      );

      return;
    }

    final int nextNumber = currentNumber + 1;

    if (nextNumber > 8) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Semester 8 is the last semester.',
          ),
        ),
      );

      return;
    }

    final String nextSemester = 'Semester $nextNumber';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Shift Student',
          ),
          content: Text(
            'Move this student from '
            '$currentSemester to $nextSemester?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                true,
              ),
              icon: const Icon(
                Icons.arrow_forward_rounded,
              ),
              label: const Text(
                'Shift',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await db.collection('users').doc(uid).update({
        'semester': nextSemester,
        'updatedAt': FieldValue.serverTimestamp(),
        'semesterShiftedAt': FieldValue.serverTimestamp(),
        'previousSemester': currentSemester,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Student shifted to '
            '$nextSemester successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Semester shift failed: $e',
          ),
        ),
      );
    }
  }

  int? _semesterNumber(String value) {
    final lower = value.toLowerCase().trim();

    final match = RegExp(r'\d+').firstMatch(lower);

    if (match != null) {
      final number = int.tryParse(match.group(0)!);

      if (number != null && number >= 1 && number <= 8) {
        return number;
      }
    }

    const names = {
      'first': 1,
      'second': 2,
      'third': 3,
      'fourth': 4,
      'fifth': 5,
      'sixth': 6,
      'seventh': 7,
      'eighth': 8,
    };

    for (final entry in names.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  // ============================================================
  // DELETE STUDENT
  // ============================================================

  Future<void> deleteStudent(String uid) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Student',
          ),
          content: const Text(
            'Are you sure you want to delete '
            'this student profile?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                false,
              ),
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                true,
              ),
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await db.collection('users').doc(uid).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Student profile deleted.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // UPLOAD NOTES
  // ============================================================

  Future<void> uploadNotes() async {
    final TextEditingController titleController = TextEditingController();

    String semester = 'Semester 1';

    try {
      // --------------------------------------------------------
      // NOTE DETAILS
      // --------------------------------------------------------

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              context,
              setDialogState,
            ) {
              return AlertDialog(
                title: const Text(
                  'Upload Chemistry Notes',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Note title',
                          hintText: 'Example: Organic Chemistry',
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: semester,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                        ),
                        items: List.generate(
                          8,
                          (index) => DropdownMenuItem<String>(
                            value: 'Semester ${index + 1}',
                            child: Text(
                              'Semester ${index + 1}',
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(
                              () {
                                semester = value;
                              },
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(
                      dialogContext,
                      false,
                    ),
                    child: const Text(
                      'Cancel',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a note title.',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    },
                    icon: const Icon(
                      Icons.upload_file_rounded,
                    ),
                    label: const Text(
                      'Continue',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true || !mounted) {
        return;
      }

      // --------------------------------------------------------
      // SOURCE
      // --------------------------------------------------------

      final String? source = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(
          0xFF10233D,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(
              24,
            ),
          ),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  const Text(
                    'Select Note Source',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.camera_alt_rounded,
                      ),
                    ),
                    title: const Text(
                      'Camera',
                    ),
                    subtitle: const Text(
                      'Take a photo of the note',
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      'camera',
                    ),
                  ),
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.photo_library_rounded,
                      ),
                    ),
                    title: const Text(
                      'Gallery',
                    ),
                    subtitle: const Text(
                      'Select an image from gallery',
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      'gallery',
                    ),
                  ),
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.folder_rounded,
                      ),
                    ),
                    title: const Text(
                      'File',
                    ),
                    subtitle: const Text(
                      'PDF, DOC, DOCX, PPT or PPTX',
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      'file',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (source == null) {
        return;
      }

      // --------------------------------------------------------
      // PICK FILE
      // --------------------------------------------------------

      Uint8List? bytes;
      String originalFileName;
      String? extension;

      if (source == 'camera' || source == 'gallery') {
        final ImagePicker picker = ImagePicker();

        final XFile? image = await picker.pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 2200,
          maxHeight: 3000,
        );

        if (image == null) {
          return;
        }

        bytes = await image.readAsBytes();

        originalFileName = image.name;

        extension = image.name.contains('.')
            ? image.name.split('.').last.toLowerCase()
            : 'jpg';
      } else {
        final FilePickerResult? picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'ppt',
            'pptx',
          ],
          withData: true,
        );

        if (picked == null || picked.files.isEmpty) {
          return;
        }

        final PlatformFile file = picked.files.first;

        bytes = file.bytes;

        if (bytes == null || bytes!.isEmpty) {
          throw Exception(
            'Unable to read selected file.',
          );
        }

        originalFileName = file.name;

        extension = file.extension?.toLowerCase();
      }

      if (bytes == null || bytes!.isEmpty) {
        throw Exception(
          'Selected file is empty.',
        );
      }

      // --------------------------------------------------------
      // LOGIN CHECK
      // --------------------------------------------------------

      final user = auth.currentUser;

      if (user == null) {
        throw Exception(
          'Please login before uploading notes.',
        );
      }

      // --------------------------------------------------------
      // FILE PATH
      // --------------------------------------------------------

      final cleanName = originalFileName.replaceAll(
        RegExp(
          r'[^a-zA-Z0-9._-]',
        ),
        '_',
      );

      final safeFileName =
          '${DateTime.now().millisecondsSinceEpoch}_$cleanName';

      final storagePath =
          '${semester.toLowerCase().replaceAll(' ', '_')}/$safeFileName';

      final contentType = _contentType(extension);

      // --------------------------------------------------------
      // UPLOAD DIALOG
      // --------------------------------------------------------

      bool uploadDialogOpen = true;

      double progress = 0.0;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: StatefulBuilder(
              builder: (
                context,
                setProgressState,
              ) {
                return AlertDialog(
                  title: const Text(
                    'Uploading Note',
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_upload_rounded,
                        size: 55,
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(
                          20,
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      const Text(
                        'Uploading, please wait...',
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );

      // --------------------------------------------------------
      // SUPABASE UPLOAD
      // --------------------------------------------------------

      try {
        final storage = supabase.storage.from('notes');

        await storage.uploadBinary(
          storagePath,
          bytes!,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

        progress = 1.0;

        // ------------------------------------------------------
        // GET PUBLIC URL
        // ------------------------------------------------------

        final fileUrl = supabase.storage.from('notes').getPublicUrl(
              storagePath,
            );

        // ------------------------------------------------------
        // FIRESTORE
        // ------------------------------------------------------

        await db.collection('notes').add({
          'title': titleController.text.trim(),
          'semester': semester,
          'fileName': originalFileName,
          'fileUrl': fileUrl,
          'storagePath': storagePath,
          'uploadedBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'storageProvider': 'supabase',
          'contentType': contentType,
        });

        if (!mounted) return;

        if (uploadDialogOpen) {
          uploadDialogOpen = false;
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notes uploaded successfully.',
            ),
          ),
        );
      } on StorageException catch (e) {
        if (mounted && uploadDialogOpen) {
          uploadDialogOpen = false;
          Navigator.of(context).pop();
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Storage error: ${e.message}',
            ),
          ),
        );

        debugPrint(
          'Supabase Storage error: ${e.message}',
        );
      } catch (e) {
        if (mounted && uploadDialogOpen) {
          uploadDialogOpen = false;
          Navigator.of(context).pop();
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: $e',
            ),
          ),
        );

        debugPrint(
          'Upload error: $e',
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Upload failed: $e',
          ),
        ),
      );
    } finally {
      titleController.dispose();
    }
  }

  // ============================================================
  // CONTENT TYPE
  // ============================================================

  String _contentType(
    String? extension,
  ) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'pdf':
        return 'application/pdf';

      case 'doc':
        return 'application/msword';

      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      case 'ppt':
        return 'application/vnd.ms-powerpoint';

      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

      default:
        return 'application/octet-stream';
    }
  }

  // ============================================================
  // CREATE NOTICE
  // ============================================================

  Future<void> createNotice() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    String semester = 'All Semesters';

    try {
      final bool? result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text(
                  'Create Notice',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Notice title',
                          hintText: 'Example: Internal Exam Notice',
                          prefixIcon: Icon(
                            Icons.title_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: messageController,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Notice message',
                          hintText: 'Write your notice here...',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 85),
                            child: Icon(
                              Icons.message_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: semester,
                        decoration: const InputDecoration(
                          labelText: 'Target semester',
                          prefixIcon: Icon(
                            Icons.school_rounded,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'All Semesters',
                            child: Text('All Semesters'),
                          ),
                          ...List.generate(
                            8,
                            (index) {
                              final value = 'Semester ${index + 1}';

                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            },
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            semester = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        dialogContext,
                      ).pop(false);
                    },
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      final title = titleController.text.trim();

                      final message = messageController.text.trim();

                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter notice title.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (message.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter notice message.',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.of(
                        dialogContext,
                      ).pop(true);
                    },
                    icon: const Icon(
                      Icons.publish_rounded,
                    ),
                    label: const Text(
                      'Publish',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) {
        return;
      }

      final user = auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Admin session expired. Please login again.',
            ),
          ),
        );

        return;
      }

      // ----------------------------------------------------------
      // SAVE NOTICE TO FIRESTORE
      // ----------------------------------------------------------

      await db.collection('notices').add({
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),

        // Student targeting
        'semester': semester,

        // Admin information
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',

        // Notice status
        'active': true,

        // Firestore server time
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notice published successfully.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notice publish failed: ${e.message ?? e.code}',
          ),
        ),
      );

      debugPrint(
        'Notice Firebase error: ${e.code} - ${e.message}',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notice publish failed: $e',
          ),
        ),
      );

      debugPrint(
        'Notice error: $e',
      );
    } finally {
      titleController.dispose();
      messageController.dispose();
    }
  }

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
          const SizedBox(
            width: 4,
          ),
        ],
      ),
      body: ChemistryBackground(
        child: SafeArea(
          top: false,
          bottom: false,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: introController,
              curve: Curves.easeOut,
            ),
            child: IndexedStack(
              index: selectedPage,
              children: [
                _dashboardPage(),
                _studentsPage(),
                _notesPage(),
                _noticesPage(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 68,
          selectedIndex: selectedPage,
          onDestinationSelected: (index) {
            if (index == selectedPage) {
              return;
            }

            setState(() {
              selectedPage = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(
                Icons.dashboard_outlined,
              ),
              selectedIcon: Icon(
                Icons.dashboard_rounded,
              ),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.people_outline_rounded,
              ),
              selectedIcon: Icon(
                Icons.people_rounded,
              ),
              label: 'Students',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.menu_book_outlined,
              ),
              selectedIcon: Icon(
                Icons.menu_book_rounded,
              ),
              label: 'Notes',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.campaign_outlined,
              ),
              selectedIcon: Icon(
                Icons.campaign_rounded,
              ),
              label: 'Notices',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _dashboardPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(
            'users',
          )
          .where(
            'role',
            isEqualTo: 'student',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(
            snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final students = snapshot.data!.docs;

        final total = students.length;

        final pending = students
            .where(
              (d) => d.data()['status'] == 'pending',
            )
            .length;

        final approved = students
            .where(
              (d) => d.data()['status'] == 'approved',
            )
            .length;

        final blocked = students
            .where(
              (d) => d.data()['status'] == 'blocked',
            )
            .length;

        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;

            final phone = w < 600;

            final tablet = w >= 600 && w < 1000;

            final cols = phone
                ? 2
                : tablet
                    ? 3
                    : 4;

            return RefreshIndicator(
              onRefresh: () async {
                if (mounted) {
                  setState(
                    () {},
                  );
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  phone ? 10 : 16,
                  12,
                  phone ? 10 : 16,
                  32,
                ),
                children: [
                  _heroHeader(),
                  const SizedBox(
                    height: 14,
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: phone ? 7 : 10,
                      mainAxisSpacing: phone ? 7 : 10,
                      childAspectRatio: phone
                          ? 1.25
                          : tablet
                              ? 1.5
                              : 1.6,
                    ),
                    itemBuilder: (_, i) => [
                      _statCard(
                        title: 'Students',
                        value: '$total',
                        icon: Icons.people_rounded,
                      ),
                      _statCard(
                        title: 'Pending',
                        value: '$pending',
                        icon: Icons.pending_actions_rounded,
                      ),
                      _statCard(
                        title: 'Approved',
                        value: '$approved',
                        icon: Icons.verified_rounded,
                      ),
                      _statCard(
                        title: 'Blocked',
                        value: '$blocked',
                        icon: Icons.block_rounded,
                      ),
                    ][i],
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  if (phone) ...[
                    _actionCard(
                      title: 'Upload Notes',
                      subtitle: 'Add semester-wise Chemistry notes',
                      icon: Icons.upload_file_rounded,
                      onTap: uploadNotes,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    _actionCard(
                      title: 'Create Notice',
                      subtitle: 'Publish important announcements',
                      icon: Icons.campaign_rounded,
                      onTap: createNotice,
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _actionCard(
                            title: 'Upload Notes',
                            subtitle: 'Add semester-wise Chemistry notes',
                            icon: Icons.upload_file_rounded,
                            onTap: uploadNotes,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: _actionCard(
                            title: 'Create Notice',
                            subtitle: 'Publish important announcements',
                            icon: Icons.campaign_rounded,
                            onTap: createNotice,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(
                    height: 18,
                  ),
                  const Text(
                    'Pending Students',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  _pendingStudentsList(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _heroHeader() {
    return LayoutBuilder(
      builder: (context, c) {
        final small = c.maxWidth < 380;

        return GlassCard(
          child: Row(
            children: [
              Container(
                width: small ? 52 : 64,
                height: small ? 52 : 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.cyan,
                      AppTheme.blue,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.science_rounded,
                  color: Colors.white,
                  size: small ? 28 : 34,
                ),
              ),
              SizedBox(
                width: small ? 10 : 14,
              ),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chemistry Control Lab',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Manage students, notes and notices.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // STUDENTS
  // ============================================================

  Widget _studentsPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(
            'users',
          )
          .where(
            'role',
            isEqualTo: 'student',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(
            snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final allDocs = snapshot.data!.docs;

        final filteredDocs = selectedStudentSemester == 'All'
            ? allDocs
            : allDocs.where(
                (doc) {
                  final data = doc.data();

                  final studentSemester = data['semester']?.toString() ?? '';

                  return _semesterMatches(
                    studentSemester,
                    selectedStudentSemester,
                  );
                },
              ).toList();

        return ListView(
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            const Text(
              'Manage Students',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            const Text(
              'View and manage students semester-wise.',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            GlassCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        13,
                      ),
                      color: AppTheme.cyan.withValues(
                        alpha: 0.10,
                      ),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: AppTheme.cyan,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Semester',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Only students from the selected semester will be shown.',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStudentSemester,
                      dropdownColor: const Color(
                        0xFF10233D,
                      ),
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.cyan,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      items: studentSemesterOptions.map(
                        (semester) {
                          return DropdownMenuItem<String>(
                            value: semester,
                            child: Text(
                              semester,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(
                          () {
                            selectedStudentSemester = value;
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedStudentSemester == 'All'
                        ? '${filteredDocs.length} registered students'
                        : '${filteredDocs.length} students in $selectedStudentSemester',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (selectedStudentSemester != 'All')
                  TextButton.icon(
                    onPressed: () {
                      setState(
                        () {
                          selectedStudentSemester = 'All';
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Show All',
                    ),
                  ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            if (filteredDocs.isEmpty)
              _emptyCard(
                icon: Icons.people_outline_rounded,
                title: selectedStudentSemester == 'All'
                    ? 'No students yet'
                    : 'No students in $selectedStudentSemester',
                subtitle: selectedStudentSemester == 'All'
                    ? 'Student registrations will appear here.'
                    : 'Students registered with $selectedStudentSemester will appear here.',
              ),
            ...filteredDocs.map(
              (doc) => _studentCard(
                doc,
              ),
            ),
          ],
        );
      },
    );
  }

  bool _semesterMatches(
    String storedSemester,
    String selectedSemester,
  ) {
    if (selectedSemester == 'All') {
      return true;
    }

    String normalizeSemester(
      String value,
    ) {
      final lower = value.toLowerCase().trim();

      final match = RegExp(r'\d+').firstMatch(
        lower,
      );

      if (match != null) {
        return match.group(0)!;
      }

      const names = {
        'first': '1',
        'second': '2',
        'third': '3',
        'fourth': '4',
        'fifth': '5',
        'sixth': '6',
        'seventh': '7',
        'eighth': '8',
      };

      for (final entry in names.entries) {
        if (lower.contains(entry.key)) {
          return entry.value;
        }
      }

      return lower
          .replaceAll('semester', '')
          .replaceAll('sem', '')
          .replaceAll('-', '')
          .replaceAll('_', '')
          .replaceAll(' ', '');
    }

    return normalizeSemester(
          storedSemester,
        ) ==
        normalizeSemester(
          selectedSemester,
        );
  }

  Widget _studentCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final String name = data['name']?.toString() ?? 'Unknown Student';

    final String email = data['email']?.toString() ?? '';

    final String studentId = data['studentId']?.toString() ?? '';

    final String semester = data['semester']?.toString() ?? '';

    final String status = data['status']?.toString() ?? 'pending';

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppTheme.cyan.withValues(
                    alpha: 0.14,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppTheme.cyan,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(
                  status,
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (studentId.isNotEmpty)
                  _infoChip(
                    Icons.badge_outlined,
                    studentId,
                  ),
                if (semester.isNotEmpty)
                  _infoChip(
                    Icons.school_outlined,
                    semester,
                  ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status != 'approved')
                  OutlinedButton.icon(
                    onPressed: () => updateStudentStatus(
                      doc.id,
                      'approved',
                    ),
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Approve',
                    ),
                  ),
                if (status != 'rejected')
                  OutlinedButton.icon(
                    onPressed: () => updateStudentStatus(
                      doc.id,
                      'rejected',
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Reject',
                    ),
                  ),
                if (_semesterNumber(semester) != null &&
                    _semesterNumber(semester)! < 8)
                  OutlinedButton.icon(
                    onPressed: () => shiftStudentSemester(
                      doc.id,
                      semester,
                    ),
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                    label: Text(
                      'Shift to Sem ${_semesterNumber(semester)! + 1}',
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  onSelected: (value) {
                    if (value == 'block') {
                      updateStudentStatus(
                        doc.id,
                        'blocked',
                      );
                    } else if (value == 'delete') {
                      deleteStudent(
                        doc.id,
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.block_rounded,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            'Block Student',
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            'Delete Profile',
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PENDING STUDENTS
  // ============================================================

  Widget _pendingStudentsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(
            'users',
          )
          .where(
            'role',
            isEqualTo: 'student',
          )
          .where(
            'status',
            isEqualTo: 'pending',
          )
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(
            snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _emptyCard(
            icon: Icons.verified_rounded,
            title: 'All clear',
            subtitle: 'There are no pending student approvals.',
          );
        }

        return Column(
          children: docs.map(
            (doc) {
              final data = doc.data();

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: GlassCard(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(
                          Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name']?.toString() ?? 'Student',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              data['email']?.toString() ?? '',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Approve',
                        onPressed: () => updateStudentStatus(
                          doc.id,
                          'approved',
                        ),
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.cyan,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reject',
                        onPressed: () => updateStudentStatus(
                          doc.id,
                          'rejected',
                        ),
                        icon: const Icon(
                          Icons.cancel_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ).toList(),
        );
      },
    );
  }

  // ============================================================
  // NOTES PAGE
  // ============================================================

  Widget _notesPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(
            'notes',
          )
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(
            snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chemistry Notes',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      Text(
                        'Manage semester-wise study material.',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                FloatingActionButton(
                  heroTag: 'notesFab',
                  onPressed: uploadNotes,
                  child: const Icon(
                    Icons.add_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            if (docs.isEmpty)
              _emptyCard(
                icon: Icons.menu_book_outlined,
                title: 'No notes uploaded',
                subtitle: 'Upload your first Chemistry note.',
              ),
            ...docs.map(
              (doc) => _noteCard(doc),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // VIEW NOTE INSIDE APP
  // ============================================================

  void _viewNote({
    required String url,
    required String title,
    required String contentType,
    required String fileName,
  }) {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note file URL is missing.'),
        ),
      );
      return;
    }

    final String lowerFileName = fileName.toLowerCase();

    final bool isPdf = contentType.toLowerCase().contains('pdf') ||
        lowerFileName.endsWith('.pdf');

    final bool isImage = contentType.toLowerCase().startsWith('image/') ||
        lowerFileName.endsWith('.jpg') ||
        lowerFileName.endsWith('.jpeg') ||
        lowerFileName.endsWith('.png') ||
        lowerFileName.endsWith('.webp');

    if (isPdf) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminPdfViewer(
            title: title,
            url: url,
          ),
        ),
      );
      return;
    }

    if (isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminImageViewer(
            title: title,
            url: url,
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Only PDF and image files can be viewed inside the app.',
        ),
      ),
    );
  }

  Widget _noteCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final String title = data['title']?.toString() ?? 'Untitled';

    final String semester = data['semester']?.toString() ?? 'Semester';

    final String fileName = data['fileName']?.toString() ?? '';

    final String fileUrl = data['fileUrl']?.toString() ?? '';

    final String contentType = data['contentType']?.toString() ?? '';

    IconData icon = Icons.insert_drive_file_rounded;

    if (contentType.contains('pdf')) {
      icon = Icons.picture_as_pdf_rounded;
    } else if (contentType.startsWith('image/') ||
        fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.png')) {
      icon = Icons.image_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  15,
                ),
                color: AppTheme.cyan.withValues(
                  alpha: 0.12,
                ),
              ),
              child: Icon(
                icon,
                color: AppTheme.cyan,
              ),
            ),
            const SizedBox(
              width: 13,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    semester,
                    style: const TextStyle(
                      color: AppTheme.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'View Note',
              onPressed: fileUrl.isEmpty
                  ? null
                  : () {
                      _viewNote(
                        url: fileUrl,
                        title: title,
                        contentType: contentType,
                        fileName: fileName,
                      );
                    },
              icon: const Icon(
                Icons.visibility_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () async {
                await _deleteNote(
                  doc,
                );
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNote(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Note?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this note? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final data = doc.data();

      final String? storagePath = data['storagePath']?.toString();

      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await supabase.storage.from('notes').remove([
            storagePath,
          ]);
        } catch (_) {}
      }

      await db.collection('notes').doc(doc.id).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Note deleted successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // NOTICES
  // ============================================================

  Widget _noticesPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection(
            'notices',
          )
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(
            snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notices',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FloatingActionButton(
                  heroTag: 'noticeFab',
                  onPressed: createNotice,
                  child: const Icon(
                    Icons.add_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            if (docs.isEmpty)
              _emptyCard(
                icon: Icons.campaign_outlined,
                title: 'No notices',
                subtitle: 'Create your first announcement.',
              ),
            ...docs.map(
              (doc) => _noticeCard(doc),
            ),
          ],
        );
      },
    );
  }

  Widget _noticeCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.cyan.withValues(
                      alpha: 0.12,
                    ),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: AppTheme.cyan,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Text(
                    data['title']?.toString() ?? 'Notice',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await db
                        .collection(
                          'notices',
                        )
                        .doc(doc.id)
                        .delete();
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              data['message']?.toString() ?? '',
              style: const TextStyle(
                color: Colors.white70,
                height: 1.45,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            _infoChip(
              Icons.school_outlined,
              data['semester']?.toString() ?? 'All Semesters',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return GlassCard(
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(
            8,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: AppTheme.cyan,
                  size: 26,
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassCard(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 68,
            maxHeight: 82,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                    color: AppTheme.cyan.withValues(
                      alpha: 0.10,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.cyan,
                    size: 21,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 4,
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(
    String status,
  ) {
    String label = status;

    IconData icon = Icons.help_outline_rounded;

    if (status == 'approved') {
      label = 'Approved';
      icon = Icons.check_circle_rounded;
    } else if (status == 'pending') {
      label = 'Pending';
      icon = Icons.pending_rounded;
    } else if (status == 'rejected') {
      label = 'Rejected';
      icon = Icons.cancel_rounded;
    } else if (status == 'blocked') {
      label = 'Blocked';
      icon = Icons.block_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          30,
        ),
        color: Colors.white.withValues(
          alpha: 0.06,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppTheme.cyan,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          30,
        ),
        color: Colors.white.withValues(
          alpha: 0.05,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white54,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 28,
          horizontal: 20,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 45,
              color: Colors.white24,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(
    String error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          20,
        ),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 45,
              ),
              const SizedBox(
                height: 12,
              ),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ADMIN PDF VIEWER
// ================================================================

class AdminPdfViewer extends StatelessWidget {
  final String title;
  final String url;

  const AdminPdfViewer({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SfPdfViewer.network(
        url,
      ),
    );
  }
}

// ================================================================
// ADMIN IMAGE VIEWER
// ================================================================

class AdminImageViewer extends StatelessWidget {
  final String title;
  final String url;

  const AdminImageViewer({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (
              context,
              child,
              loadingProgress,
            ) {
              if (loadingProgress == null) {
                return child;
              }

              return const SizedBox(
                width: 45,
                height: 45,
                child: CircularProgressIndicator(),
              );
            },
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load this image.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
