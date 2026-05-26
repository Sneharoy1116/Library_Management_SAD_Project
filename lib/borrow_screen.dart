import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BorrowScreen extends StatefulWidget {
  const BorrowScreen({super.key});

  @override
  State<BorrowScreen> createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  List<Map<String, dynamic>> _borrowRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBorrowRecords();
  }

  // Fetch all borrowed books for current user
  Future<void> _fetchBorrowRecords() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('borrowing_records')
          .select('''
            *,
            library_books (
              title,
              author
            )
          ''')
          .eq('user_id', user.id)
          .order('borrow_date', ascending: false);

      setState(() => _borrowRecords = response);
    } catch (error) {
      print('Error fetching borrow records: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${error.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Return a book
  Future<void> _returnBook(String recordId, String bookTitle, String bookId, int currentAvailableCopies) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Book'),
        content: Text('Are you sure you want to return "$bookTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Return'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Update return date in borrowing_records
      await Supabase.instance.client
          .from('borrowing_records')
          .update({
            'return_date': DateTime.now().toIso8601String().split('T')[0],
          })
          .eq('id', recordId);
      
      // Increase available copies in library_books
      await Supabase.instance.client
          .from('library_books')
          .update({'available_copies': currentAvailableCopies + 1})
          .eq('id', bookId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully returned "$bookTitle"')),
      );
      
      // Refresh the list
      await _fetchBorrowRecords();
      
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error returning book: ${error.toString()}')),
      );
    }
  }

  // Format date for display
  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not returned yet';
    // Convert YYYY-MM-DD to more readable format
    final parts = dateString.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dateString;
  }

  // Calculate days since borrowed
  int _calculateDays(String borrowDate) {
    try {
      final borrowed = DateTime.parse(borrowDate);
      final now = DateTime.now();
      return now.difference(borrowed).inDays;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchBorrowRecords,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _borrowRecords.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_late, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No borrowed books',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Go to Books tab to borrow some books',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _borrowRecords.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final record = _borrowRecords[index];
                      final book = record['library_books'] as Map<String, dynamic>;
                      final isReturned = record['return_date'] != null;
                      final daysPassed = !isReturned ? _calculateDays(record['borrow_date']) : 0;
                      final isOverdue = daysPassed > 14; // 14 days borrowing period
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isReturned ? Colors.grey.shade50 : Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Book Title and Status
                                Row(
                                  children: [
                                    Icon(
                                      Icons.book,
                                      size: 30,
                                      color: isReturned ? Colors.grey : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            book['title'],
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isReturned ? Colors.grey : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            'by ${book['author']}',
                                            style: TextStyle(
                                              color: isReturned ? Colors.grey.shade600 : Colors.grey.shade700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isReturned
                                            ? Colors.green.shade100
                                            : isOverdue
                                                ? Colors.red.shade100
                                                : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isReturned
                                            ? 'RETURNED'
                                            : isOverdue
                                                ? 'OVERDUE'
                                                : 'BORROWED',
                                        style: TextStyle(
                                          color: isReturned
                                              ? Colors.green.shade800
                                              : isOverdue
                                                  ? Colors.red.shade800
                                                  : Colors.orange.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Borrow Date
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Borrowed: ${_formatDate(record['borrow_date'])}',
                                      style: TextStyle(
                                        color: isReturned ? Colors.grey.shade600 : Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Days info (for active borrowings)
                                if (!isReturned) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.timer, size: 16, color: isOverdue ? Colors.red : Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$daysPassed days ago',
                                        style: TextStyle(
                                          color: isOverdue ? Colors.red : Colors.grey.shade600,
                                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.event, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Due: ${_formatDate(record['borrow_date'].split('T')[0])} + 14 days',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Return Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _returnBook(
                                        record['id'],
                                        book['title'],
                                        book['id'],
                                        book['available_copies'],
                                      ),
                                      icon: const Icon(Icons.assignment_return),
                                      label: const Text('Return Book'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                
                                // Return date (for returned books)
                                if (isReturned) ...[
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Returned: ${_formatDate(record['return_date'])}',
                                        style: TextStyle(color: Colors.green.shade700),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}