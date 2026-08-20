import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/chemistry_background.dart';
import '../../core/theme.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();

  String _selectedSemester = 'Semester 1';
  bool _uploading = false;

  final List<String> _semesters = const [
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
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ---------------- CAMERA ----------------

  Future<void> _openCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2200,
        maxHeight: 3000,
      );

      if (image == null) return;

      if (!mounted) return;
      await _askTitleAndUpload(
        File(image.path),
        source: 'camera',
        extension: 'jpg',
        contentType: 'image/jpeg',
      );
    } catch (e) {
      _showMessage('Camera failed: $e', error: true);
    }
  }

  // ---------------- GALLERY ----------------

  Future<void> _openGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2200,
        maxHeight: 3000,
      );

      if (image == null) return;

      final extension = _extension(image.path);
      final contentType = _imageContentType(extension);

      if (!mounted) return;
      await _askTitleAndUpload(
        File(image.path),
        source: 'gallery',
        extension: extension,
        contentType: contentType,
      );
    } catch (e) {
      _showMessage('Gallery failed: $e', error: true);
    }
  }

  // ---------------- FILE / PDF ----------------

  Future<void> _openFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final path = picked.path;

      if (path == null || path.isEmpty) {
        _showMessage(
          'Could not access the selected file.',
          error: true,
        );
        return;
      }

      final extension = _extension(path);
      final contentType = _contentType(extension);

      if (!mounted) return;
      await _askTitleAndUpload(
        File(path),
        source: 'file',
        extension: extension,
        contentType: contentType,
        suggestedTitle: picked.name,
      );
    } catch (e) {
      _showMessage('File picker failed: $e', error: true);
    }
  }

  // ---------------- TITLE + UPLOAD ----------------

  Future<void> _askTitleAndUpload(
    File file, {
    required String source,
    required String extension,
    required String contentType,
    String? suggestedTitle,
  }) async {
    _titleController.text = _cleanFileTitle(suggestedTitle ?? '');

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Note'),
          content: TextField(
            controller: _titleController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Note title',
              hintText: 'Example: Organic Chemistry',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final value = _titleController.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(dialogContext, value);
              },
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Upload'),
            ),
          ],
        );
      },
    );

    if (title == null || title.trim().isEmpty) {
      _titleController.clear();
      return;
    }

    await _uploadToSupabase(
      file,
      title.trim(),
      source: source,
      extension: extension,
      contentType: contentType,
    );
  }

  Future<void> _uploadToSupabase(
    File file,
    String title, {
    required String source,
    required String extension,
    required String contentType,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please login first.', error: true);
      return;
    }

    if (!await file.exists()) {
      _showMessage('Selected file no longer exists.', error: true);
      return;
    }

    if (mounted) setState(() => _uploading = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeExtension = extension.isEmpty ? 'bin' : extension.toLowerCase();
      final fileName = '${timestamp}_${source}_$safeExtension';
      final storagePath =
          '${_selectedSemester.toLowerCase().replaceAll(' ', '_')}/${user.uid}/$fileName';

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('Selected file is empty.');

      await _supabase.storage.from('notes').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );

      final fileUrl = _supabase.storage.from('notes').getPublicUrl(storagePath);

      await _firestore.collection('notes').add({
        'title': title,
        'semester': _selectedSemester,
        'fileName': fileName,
        'originalFileName': file.path.split(Platform.pathSeparator).last,
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'type': _isImage(extension) ? 'image' : 'file',
        'source': source,
        'uploadedBy': user.uid,
        'uploadedByEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'storageProvider': 'supabase',
      });

      _titleController.clear();
      _showMessage('Note uploaded successfully.');
    } on StorageException catch (e) {
      _showMessage('Supabase Storage error: ${e.message}', error: true);
      debugPrint('Supabase Storage error: ${e.message}');
    } catch (e) {
      _showMessage('Upload failed: $e', error: true);
      debugPrint('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ---------------- DELETE ----------------

  Future<void> _deleteNote(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final path = data['storagePath']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text(
          'This note will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (path.isNotEmpty) {
        try {
          await _supabase.storage.from('notes').remove([path]);
        } catch (e) {
          debugPrint('Storage delete skipped: $e');
        }
      }

      await _firestore.collection('notes').doc(doc.id).delete();
      _showMessage('Note deleted.');
    } catch (e) {
      _showMessage('Delete failed: $e', error: true);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chemistry Notes',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ChemistryBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(child: _notesList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _showUploadOptions,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Note'),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Study Materials',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Upload notes using camera, gallery or files.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSemester,
                isExpanded: true,
                dropdownColor: const Color(0xFF13243A),
                items: _semesters
                    .map(
                      (semester) => DropdownMenuItem(
                        value: semester,
                        child: Text(semester),
                      ),
                    )
                    .toList(),
                onChanged: _uploading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedSemester = value);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('notes')
          .where(
            'semester',
            isEqualTo: _selectedSemester,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorWidget(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyWidget();
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _noteCard(docs[index]);
          },
        );
      },
    );
  }

  Widget _noteCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final title = data['title']?.toString() ?? 'Chemistry Note';
    final fileName = data['originalFileName']?.toString() ??
        data['fileName']?.toString() ??
        '';
    final source = data['source']?.toString() ?? 'file';
    final type = data['type']?.toString() ?? 'file';
    final url = data['fileUrl']?.toString() ?? '';

    final isImage = type == 'image' || _isImage(_extension(fileName));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: AppTheme.cyan.withValues(alpha: 0.10),
            ),
            child: Icon(
              isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
              color: AppTheme.cyan,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _selectedSemester,
                  style: const TextStyle(
                    color: AppTheme.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  source == 'camera'
                      ? '📷 Camera'
                      : source == 'gallery'
                          ? '🖼️ Gallery'
                          : '📄 File',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
                if (fileName.isNotEmpty)
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open',
            onPressed: url.isEmpty
                ? null
                : () => _openPreview(
                      url,
                      title,
                      isImage,
                    ),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteNote(doc);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded),
                    SizedBox(width: 10),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openPreview(
    String url,
    String title,
    bool isImage,
  ) {
    if (isImage) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(30),
                child: Text('Unable to load image.'),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // PDF/file opening can be handled with your existing PDF viewer
    // package or url launcher. The download URL is available in Firestore.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(
          'This is a file note. Connect your existing PDF viewer here '
          'to preview PDF files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------------- UPLOAD OPTIONS ----------------

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10243A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Add Chemistry Note',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _uploadOption(
                  icon: Icons.camera_alt_rounded,
                  title: 'Take Photo',
                  subtitle: 'Open camera and scan the note',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 250),
                    );
                    if (mounted) {
                      await _openCamera();
                    }
                  },
                ),
                _uploadOption(
                  icon: Icons.photo_library_rounded,
                  title: 'Choose from Gallery',
                  subtitle: 'Select an image of the note',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 250),
                    );
                    if (mounted) {
                      await _openGallery();
                    }
                  },
                ),
                _uploadOption(
                  icon: Icons.attach_file_rounded,
                  title: 'Choose File / PDF',
                  subtitle: 'Upload PDF or document',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 250),
                    );
                    if (mounted) {
                      await _openFilePicker();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _uploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.cyan.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          color: AppTheme.cyan,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.white38,
      ),
      onTap: onTap,
    );
  }

  Widget _emptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 60,
              color: Colors.white24,
            ),
            const SizedBox(height: 15),
            const Text(
              'No Notes Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Add a note using camera, gallery or file.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Error:\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.orangeAccent,
          ),
        ),
      ),
    );
  }

  // ---------------- HELPERS ----------------

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) {
      return '';
    }
    return path.substring(dot + 1).toLowerCase();
  }

  bool _isImage(String extension) {
    return const [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
    ].contains(extension.toLowerCase());
  }

  String _imageContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _contentType(String extension) {
    switch (extension.toLowerCase()) {
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
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  String _cleanFileTitle(String value) {
    if (value.isEmpty) return '';
    final dot = value.lastIndexOf('.');
    if (dot > 0) {
      return value.substring(0, dot);
    }
    return value;
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.redAccent : null,
        ),
      );
  }
}
