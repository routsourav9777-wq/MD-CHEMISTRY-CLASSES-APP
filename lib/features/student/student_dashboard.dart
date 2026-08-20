import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/chemistry_background.dart';
import '../../core/theme.dart';
import '../auth/login_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _selectedIndex = 0;

  String _studentName = 'Student';
  String _studentId = '';
  String _semester = '';
  String _email = '';
  String _photoUrl = '';

  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> _loadStudentProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loadingProfile = false;
      });

      return;
    }

    try {
      final doc = await _db.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        if (!mounted) return;

        setState(() {
          _studentName = _getString(
            data,
            [
              'name',
              'studentName',
              'fullName',
            ],
            user.displayName ?? 'Student',
          );

          _studentId = _getString(
            data,
            [
              'studentId',
              'studentID',
              'rollNumber',
              'rollNo',
              'id',
            ],
            '',
          );

          _semester = _getString(
            data,
            [
              'semester',
              'sem',
            ],
            '',
          );

          _email = _getString(
            data,
            [
              'email',
            ],
            user.email ?? '',
          );

          _photoUrl = _getString(
            data,
            [
              'photoUrl',
              'profilePhoto',
              'profileImage',
            ],
            user.photoURL ?? '',
          );

          _loadingProfile = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          _studentName = user.displayName ?? 'Student';

          _email = user.email ?? '';

          _loadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Student profile error: $e',
      );

      if (!mounted) return;

      setState(() {
        _studentName = user.displayName ?? 'Student';

        _email = user.email ?? '';

        _loadingProfile = false;
      });
    }
  }

  String _getString(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return fallback;
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    try {
      await _auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint(
        'Logout error: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logout failed: $e',
          ),
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Logout?',
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(
                  dialogContext,
                );

                await _logout();
              },
              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // OPEN NOTE
  // ============================================================

  Future<void> _openNote(
    Map<String, dynamic> data,
  ) async {
    final String url = _getString(
      data,
      [
        'fileUrl',
        'downloadUrl',
        'url',
        'fileURL',
      ],
      '',
    );

    if (url.isEmpty) {
      _showMessage(
        'This note does not have a valid file.',
        error: true,
      );

      return;
    }

    final String fileName = _getString(
      data,
      [
        'fileName',
        'name',
        'title',
      ],
      'Chemistry Note',
    );

    final String extension = _getExtension(
      fileName,
      url,
    );

    // ==========================================================
    // PDF
    // ==========================================================

    if (extension == 'pdf') {
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfNoteViewer(
            title: fileName,
            url: url,
          ),
        ),
      );

      return;
    }

    // ==========================================================
    // IMAGE
    // ==========================================================

    if (_isImage(extension)) {
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageNoteViewer(
            title: fileName,
            url: url,
          ),
        ),
      );

      return;
    }

    // ==========================================================
    // OTHER FILE
    // ==========================================================

    _showMessage(
      'This file type is not supported inside the app.',
      error: true,
    );
  }

  String _getExtension(
    String fileName,
    String url,
  ) {
    String name = fileName.trim();

    if (name.contains('.')) {
      return name.split('.').last.toLowerCase();
    }

    try {
      final uri = Uri.parse(url);

      final path = uri.path.toLowerCase();

      if (path.contains('.')) {
        return path.split('.').last.split('?').first.split('#').first;
      }
    } catch (_) {}

    return '';
  }

  bool _isImage(
    String extension,
  ) {
    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          backgroundColor: error ? Colors.redAccent : null,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chemistry Hub',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showProfile,
            tooltip: 'Profile',
            icon: const Icon(
              Icons.person_outline_rounded,
            ),
          ),
          IconButton(
            onPressed: _showLogoutDialog,
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),
      body: ChemistryBackground(
        child: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _homePage(),
              _notesPage(),
              _noticesPage(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
            ),
            label: 'Home',
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
    );
  }

  // ============================================================
  // HOME
  // ============================================================

  Widget _homePage() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        _welcomeCard(),
        const SizedBox(
          height: 18,
        ),
        Row(
          children: [
            Expanded(
              child: _featureTile(
                title: 'Notes',
                subtitle: 'Chemistry study materials',
                icon: Icons.menu_book_rounded,
                onTap: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: _featureTile(
                title: 'Notices',
                subtitle: 'Latest coaching updates',
                icon: Icons.campaign_rounded,
                onTap: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 18,
        ),
        _studentInfoCard(),
        const SizedBox(
          height: 18,
        ),
        _chemistryFactCard(),
      ],
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0E3852),
            Color(0xFF101D45),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.cyan.withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Row(
        children: [
          _profileAvatar(),
          const SizedBox(
            width: 15,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                _loadingProfile
                    ? const SizedBox(
                        width: 100,
                        height: 22,
                        child: LinearProgressIndicator(),
                      )
                    : Text(
                        _studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                const SizedBox(
                  height: 6,
                ),
                Text(
                  _semester.isEmpty
                      ? 'Your Chemistry Hub'
                      : 'Semester $_semester',
                  style: const TextStyle(
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE AVATAR
  // ============================================================

  Widget _profileAvatar() {
    if (_photoUrl.isNotEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.cyan,
            width: 2,
          ),
          image: DecorationImage(
            image: NetworkImage(_photoUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.cyan.withValues(
          alpha: 0.10,
        ),
        border: Border.all(
          color: AppTheme.cyan.withValues(
            alpha: 0.45,
          ),
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: AppTheme.cyan,
        size: 34,
      ),
    );
  }

  // ============================================================
  // FEATURE TILE
  // ============================================================

  Widget _featureTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.055,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.08,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    15,
                  ),
                  color: AppTheme.cyan.withValues(
                    alpha: 0.10,
                  ),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.cyan,
                  size: 28,
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STUDENT INFO
  // ============================================================

  Widget _studentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.045,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          _infoRow(
            Icons.person_outline_rounded,
            _studentName,
          ),
          if (_studentId.isNotEmpty)
            _infoRow(
              Icons.badge_outlined,
              _studentId,
            ),
          if (_semester.isNotEmpty)
            _infoRow(
              Icons.school_outlined,
              _semester,
            ),
          if (_email.isNotEmpty)
            _infoRow(
              Icons.email_outlined,
              _email,
            ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 11,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: AppTheme.cyan,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHEMISTRY FACT
  // ============================================================

  Widget _chemistryFactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.045,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🧪 Chemistry Fact',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(
            height: 9,
          ),
          Text(
            'The atomic number of carbon is 6. '
            'Its symbol is C and it forms the backbone '
            'of many organic compounds.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTES
  // ============================================================

  Widget _notesPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('notes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorWidget(
            'Unable to load notes.\n\n'
            '${snapshot.error}',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final filteredDocs = docs.where((doc) {
          final data = doc.data();

          if (_semester.isEmpty) {
            return true;
          }

          final noteSemester = _getString(
            data,
            [
              'semester',
              'sem',
            ],
            '',
          );

          if (noteSemester.isEmpty) {
            return true;
          }

          return _sameSemester(
            noteSemester,
            _semester,
          );
        }).toList();

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Chemistry Notes',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Text(
              _semester.isEmpty
                  ? 'Study materials'
                  : 'Notes for Semester $_semester',
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            if (filteredDocs.isEmpty)
              _emptyWidget(
                Icons.menu_book_outlined,
                'No Notes Available',
                'Notes uploaded for your semester '
                    'will appear here.',
              ),
            ...filteredDocs.map(
              _buildNoteCard,
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // NOTE CARD
  // ============================================================

  Widget _buildNoteCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final title = _getString(
      data,
      [
        'title',
        'noteTitle',
        'name',
      ],
      'Chemistry Note',
    );

    final semester = _getString(
      data,
      [
        'semester',
        'sem',
      ],
      'All Semesters',
    );

    final fileName = _getString(
      data,
      [
        'fileName',
        'name',
      ],
      '',
    );

    final fileUrl = _getString(
      data,
      [
        'fileUrl',
        'downloadUrl',
        'url',
        'fileURL',
      ],
      '',
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: fileUrl.isEmpty
              ? () {
                  _showMessage(
                    'File is not available.',
                    error: true,
                  );
                }
              : () {
                  _openNote(data);
                },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.05,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.07,
                ),
              ),
            ),
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
                      alpha: 0.10,
                    ),
                  ),
                  child: Icon(
                    _fileIcon(
                      fileName,
                    ),
                    color: AppTheme.cyan,
                    size: 27,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        semester,
                        style: const TextStyle(
                          color: AppTheme.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (fileName.isNotEmpty) ...[
                        const SizedBox(
                          height: 4,
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
                    ],
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons.visibility_rounded,
                    color: AppTheme.cyan,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _fileIcon(
    String fileName,
  ) {
    final name = fileName.toLowerCase();

    if (name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }

    if (name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp')) {
      return Icons.image_rounded;
    }

    if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.description_rounded;
    }

    if (name.endsWith('.ppt') || name.endsWith('.pptx')) {
      return Icons.slideshow_rounded;
    }

    return Icons.insert_drive_file_rounded;
  }

  // ============================================================
  // NOTICES
  // ============================================================

  Widget _noticesPage() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('notices').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorWidget(
            'Unable to load notices.\n\n'
            '${snapshot.error}',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        final noticeDocs = allDocs.where((doc) {
          final data = doc.data();

          if (data.containsKey(
            'active',
          )) {
            if (data['active'] == false) {
              return false;
            }
          }

          final noticeSemester = _getString(
            data,
            [
              'semester',
              'sem',
              'targetSemester',
            ],
            '',
          );

          if (noticeSemester.isEmpty) {
            return true;
          }

          if (_semester.isEmpty) {
            return true;
          }

          return _sameSemester(
            noticeSemester,
            _semester,
          );
        }).toList();

        noticeDocs.sort(
          (a, b) {
            final aTime = _timestampValue(
              a.data(),
            );

            final bTime = _timestampValue(
              b.data(),
            );

            return bTime.compareTo(
              aTime,
            );
          },
        );

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Latest Notices',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            const Text(
              'Important updates from your '
              'Chemistry coaching centre.',
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            if (noticeDocs.isEmpty)
              _emptyWidget(
                Icons.campaign_outlined,
                'No Notices',
                'New notices from your coaching '
                    'centre will appear here.',
              ),
            ...noticeDocs.map(
              _buildNoticeCard,
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoticeCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final title = _getString(
      data,
      [
        'title',
        'noticeTitle',
        'subject',
        'name',
      ],
      'Important Notice',
    );

    final message = _getString(
      data,
      [
        'message',
        'description',
        'content',
        'notice',
        'body',
      ],
      'No notice details available.',
    );

    final semester = _getString(
      data,
      [
        'semester',
        'sem',
        'targetSemester',
      ],
      'All Students',
    );

    final createdBy = _getString(
      data,
      [
        'createdBy',
        'uploadedBy',
        'author',
        'adminName',
      ],
      '',
    );

    final date = _formatTimestamp(
      _timestampValue(data),
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.05,
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: AppTheme.cyan.withValues(
            alpha: 0.10,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cyan.withValues(
                    alpha: 0.10,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.55,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _noticeChip(
                Icons.school_outlined,
                semester,
              ),
              if (createdBy.isNotEmpty)
                _noticeChip(
                  Icons.person_outline_rounded,
                  createdBy,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noticeChip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: AppTheme.cyan.withValues(
          alpha: 0.08,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: AppTheme.cyan,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE DIALOG
  // ============================================================

  void _showProfile() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'My Profile',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _profileAvatar(),
                const SizedBox(
                  height: 18,
                ),
                _dialogRow(
                  'Name',
                  _studentName,
                ),
                _dialogRow(
                  'Student ID',
                  _studentId.isEmpty ? 'Not available' : _studentId,
                ),
                _dialogRow(
                  'Semester',
                  _semester.isEmpty ? 'Not available' : _semester,
                ),
                _dialogRow(
                  'Email',
                  _email.isEmpty ? 'Not available' : _email,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogRow(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _emptyWidget(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 35,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.045,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
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
            height: 6,
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorWidget(
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.05,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.orangeAccent,
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
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _sameSemester(
    String first,
    String second,
  ) {
    String clean(String value) {
      return value
          .toLowerCase()
          .replaceAll(
            'semester',
            '',
          )
          .replaceAll(
            'sem',
            '',
          )
          .replaceAll(
            ' ',
            '',
          )
          .trim();
    }

    return clean(first) == clean(second);
  }

  int _timestampValue(
    Map<String, dynamic> data,
  ) {
    final value = data['createdAt'];

    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }

  String _formatTimestamp(
    int milliseconds,
  ) {
    if (milliseconds <= 0) {
      return '';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
    );

    final day = date.day.toString().padLeft(
          2,
          '0',
        );

    final month = date.month.toString().padLeft(
          2,
          '0',
        );

    return '$day/$month/${date.year}';
  }
}

// ==================================================================
// PDF VIEWER
// ==================================================================

class PdfNoteViewer extends StatefulWidget {
  final String title;
  final String url;

  const PdfNoteViewer({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<PdfNoteViewer> createState() => _PdfNoteViewerState();
}

class _PdfNoteViewerState extends State<PdfNoteViewer> {
  final PdfViewerController _pdfController = PdfViewerController();

  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          SfPdfViewer.network(
            widget.url,
            controller: _pdfController,
            enableDoubleTapZooming: true,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            onDocumentLoaded: (details) {
              if (!mounted) return;

              setState(() {
                _loading = false;
              });
            },
            onDocumentLoadFailed: (details) {
              if (!mounted) return;

              setState(() {
                _loading = false;
              });

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content: Text(
                    'PDF load failed: '
                    '${details.description}',
                  ),
                ),
              );
            },
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

// ==================================================================
// IMAGE VIEWER
// ==================================================================

class ImageNoteViewer extends StatefulWidget {
  final String title;
  final String url;

  const ImageNoteViewer({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<ImageNoteViewer> createState() => _ImageNoteViewerState();
}

class _ImageNoteViewerState extends State<ImageNoteViewer> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              panEnabled: true,
              scaleEnabled: true,
              child: Image.network(
                widget.url,
                fit: BoxFit.contain,
                loadingBuilder: (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    if (_loading) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) {
                          if (!mounted) return;

                          setState(() {
                            _loading = false;
                          });
                        },
                      );
                    }

                    return child;
                  }

                  return const SizedBox();
                },
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  if (_loading) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) {
                        if (!mounted) return;

                        setState(() {
                          _loading = false;
                        });
                      },
                    );
                  }

                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          size: 65,
                          color: Colors.white38,
                        ),
                        SizedBox(
                          height: 15,
                        ),
                        Text(
                          'Unable to load image',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
