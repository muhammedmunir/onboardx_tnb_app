import 'package:flutter/material.dart';

class PreChatFormScreen extends StatefulWidget {
  final String supportType;
  final Function(String) onStartChat;

  const PreChatFormScreen({
    Key? key,
    required this.supportType,
    required this.onStartChat,
  }) : super(key: key);

  @override
  _PreChatFormScreenState createState() => _PreChatFormScreenState();
}

class _PreChatFormScreenState extends State<PreChatFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = '';
  String _issueDescription = '';

  final List<String> _techCategories = [
    'Software Issue',
    'Hardware Problem',
    'Access & Login',
    'Network & Connectivity',
    'Other Technical Issue'
  ];

  final List<String> _hrCategories = [
    'Benefits & Compensation',
    'Company Policies',
    'Onboarding Process',
    'Training & Development',
    'Workplace Culture',
    'Other HR Question'
  ];

  List<String> get _categories {
    return widget.supportType == 'Technical Support' 
        ? _techCategories 
        : _hrCategories;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.supportType} Help'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell us about your issue',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                value: _selectedCategory.isEmpty ? null : _selectedCategory,
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Issue Description
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Describe your issue',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe your issue';
                  }
                  if (value.length < 10) {
                    return 'Please provide more details (at least 10 characters)';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _issueDescription = value;
                  });
                },
              ),
              SizedBox(height: 24),

              // Start Chat Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _startChat,
                  child: Text(
                    'Start Chat',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

              // Quick Help Section
              SizedBox(height: 32),
              Text(
                'Quick Help',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Common questions might be answered in our FAQ section.',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Navigate to FAQ
                },
                child: Text('Browse FAQ Section'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startChat() {
    if (_formKey.currentState!.validate()) {
      final fullMessage = 'Category: $_selectedCategory\n\nIssue: $_issueDescription';
      widget.onStartChat(fullMessage);
    }
  }
}