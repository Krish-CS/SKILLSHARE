import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/job_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/app_helpers.dart';
import '../../utils/app_dialog.dart';

class CreateJobScreen extends StatefulWidget {
  final JobModel? existingJob;

  const CreateJobScreen({super.key, this.existingJob});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _skillController = TextEditingController();
  
  final FirestoreService _firestoreService = FirestoreService();
  
  String? _selectedJobType;
  final List<String> _requiredSkills = [];
  DateTime? _selectedDeadline;
  bool _isLoading = false;

  bool get _isEditing => widget.existingJob != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    final job = widget.existingJob;
    if (job != null) {
      _titleController.text = job.title;
      _descriptionController.text = job.description;
      _locationController.text = job.location;
      _budgetMinController.text = job.budgetMin?.toStringAsFixed(0) ?? '';
      _budgetMaxController.text = job.budgetMax?.toStringAsFixed(0) ?? '';
      _selectedJobType = job.jobType.isNotEmpty
          ? job.jobType[0].toUpperCase() + job.jobType.substring(1)
          : null;
      _requiredSkills.addAll(job.requiredSkills);
      _selectedDeadline = job.deadline;
    }
  }

  final List<String> _jobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2196F3),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  void _addSkill() {
    final skill = _skillController.text.trim();
    if (skill.isNotEmpty && !_requiredSkills.contains(skill)) {
      setState(() {
        _requiredSkills.add(skill);
        _skillController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _requiredSkills.remove(skill);
    });
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedJobType == null) {
      AppDialog.info(context, 'Please select a job type');
      return;
    }

    if (_selectedDeadline == null) {
      AppDialog.info(context, 'Please select a deadline');
      return;
    }

    if (_requiredSkills.isEmpty) {
      AppDialog.info(context, 'Please add at least one required skill');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();

      if (_isEditing) {
        final updatedJob = JobModel(
          id: widget.existingJob!.id,
          companyId: widget.existingJob!.companyId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          requiredSkills: _requiredSkills,
          location: _locationController.text.trim(),
          budgetMin: _budgetMinController.text.isNotEmpty
              ? double.parse(_budgetMinController.text.trim())
              : null,
          budgetMax: _budgetMaxController.text.isNotEmpty
              ? double.parse(_budgetMaxController.text.trim())
              : null,
          jobType: _selectedJobType!.toLowerCase(),
          status: widget.existingJob!.status,
          applicants: widget.existingJob!.applicants,
          selectedApplicant: widget.existingJob!.selectedApplicant,
          deadline: _selectedDeadline!,
          createdAt: widget.existingJob!.createdAt,
          updatedAt: now,
        );
        await _firestoreService.updateJob(updatedJob);
        if (mounted) {
          AppDialog.success(context, 'Job updated successfully!',
              onDismiss: () => Navigator.of(context).pop(true));
        }
      } else {
        final job = JobModel(
          id: '',
          companyId: userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          requiredSkills: _requiredSkills,
          location: _locationController.text.trim(),
          budgetMin: _budgetMinController.text.isNotEmpty
              ? double.parse(_budgetMinController.text.trim())
              : null,
          budgetMax: _budgetMaxController.text.isNotEmpty
              ? double.parse(_budgetMaxController.text.trim())
              : null,
          jobType: _selectedJobType!.toLowerCase(),
          status: 'open',
          deadline: _selectedDeadline!,
          createdAt: now,
          updatedAt: now,
        );
        await _firestoreService.createJob(job);
        if (mounted) {
          AppDialog.success(context, 'Job posted successfully!',
              onDismiss: () => Navigator.of(context).pop(true));
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialog.error(context, 'Error posting job', detail: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    
    // CRITICAL: Only companies and customers can post jobs
    if (!authProvider.canPostJobs) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Post Job'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Only customers and companies can post jobs. Skilled persons can apply to available jobs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Job' : 'Post a Job',
            style: const TextStyle(color: Colors.white)),
      flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Job Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Job Title *',
                hintText: 'e.g., Senior Flutter Developer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.work),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a job title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Job Type
            DropdownButtonFormField<String>(
              value: _selectedJobType,
              decoration: InputDecoration(
                labelText: 'Job Type *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.category),
              ),
              items: _jobTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedJobType = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a job type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Job Description *',
                hintText: 'Describe the role, responsibilities, requirements...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a job description';
                }
                if (value.trim().length < 50) {
                  return 'Description must be at least 50 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location *',
                hintText: 'e.g., New York, NY or Remote',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_on),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a location';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Budget Range
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _budgetMinController,
                    decoration: InputDecoration(
                      labelText: 'Min Budget',
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final amount = double.tryParse(value);
                        if (amount == null || amount < 0) {
                          return 'Invalid amount';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _budgetMaxController,
                    decoration: InputDecoration(
                      labelText: 'Max Budget',
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final amount = double.tryParse(value);
                        if (amount == null || amount < 0) {
                          return 'Invalid amount';
                        }
                        if (_budgetMinController.text.isNotEmpty) {
                          final minAmount = double.parse(_budgetMinController.text);
                          if (amount < minAmount) {
                            return 'Max must be >= Min';
                          }
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Deadline
            InkWell(
              onTap: _selectDeadline,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDeadline == null
                            ? 'Select Deadline *'
                            : 'Deadline: ${AppHelpers.formatDate(_selectedDeadline!)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedDeadline == null
                              ? Colors.grey[600]
                              : Colors.black,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Required Skills
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Required Skills *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Skill Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _skillController,
                            decoration: InputDecoration(
                              hintText: 'Add a skill',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _addSkill(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addSkill,
                          icon: const Icon(Icons.add_circle),
                          color: const Color(0xFF2196F3),
                          iconSize: 32,
                        ),
                      ],
                    ),
                    
                    // Skills List
                    if (_requiredSkills.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _requiredSkills.map((skill) {
                          return Chip(
                            label: Text(skill),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeSkill(skill),
                            backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.1),
                            labelStyle: const TextStyle(
                              color: Color(0xFF2196F3),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Update Job' : 'Post Job',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
