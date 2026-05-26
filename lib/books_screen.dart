import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  List<Map<String, dynamic>> _books = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  // Fetch all books
  Future<void> _fetchBooks() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('library_books')
          .select('*')
          .order('title');
      
      setState(() => _books = response);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching books: ${error.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Search books
  Future<void> _searchBooks(String query) async {
    if (query.isEmpty) {
      await _fetchBooks();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('library_books')
          .select('*')
          .or('title.ilike.%$query%,author.ilike.%$query%')
          .order('title');
      
      setState(() => _books = response);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching books: ${error.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Add new book
  Future<void> _addBook() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final copiesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                labelText: 'Author',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: copiesController,
              decoration: const InputDecoration(
                labelText: 'Total Copies',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final author = authorController.text.trim();
              final copies = int.tryParse(copiesController.text.trim()) ?? 1;
              
              if (title.isNotEmpty && author.isNotEmpty) {
                try {
                  await Supabase.instance.client.from('library_books').insert({
                    'title': title,
                    'author': author,
                    'total_copies': copies,
                    'available_copies': copies,
                  });
                  
                  Navigator.pop(context);
                  _fetchBooks();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Book added successfully!')),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding book: ${error.toString()}')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
              }
            },
            child: const Text('Add Book'),
          ),
        ],
      ),
    );
  }

  // Borrow a book
  Future<void> _borrowBook(String bookId, String title, int availableCopies) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    // Check if user already borrowed this book and not returned
    try {
      // Alternative approach: fetch all records and filter in code
      final existingBorrow = await Supabase.instance.client
          .from('borrowing_records')
          .select('return_date')
          .eq('user_id', user.id)
          .eq('book_id', bookId);
      
      // Check if there's any record without return_date (still borrowed)
      bool alreadyBorrowed = false;
      for (var record in existingBorrow) {
        if (record['return_date'] == null) {
          alreadyBorrowed = true;
          break;
        }
      }
      
      if (alreadyBorrowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already borrowed this book and not returned yet!')),
        );
        return;
      }
    } catch (error) {
      print('Error checking existing borrow: $error');
    }

    try {
      // Add borrow record
      await Supabase.instance.client.from('borrowing_records').insert({
        'user_id': user.id,
        'book_id': bookId,
        'borrow_date': DateTime.now().toIso8601String().split('T')[0],
      });
      
      // Decrease available copies
      await Supabase.instance.client
          .from('library_books')
          .update({'available_copies': availableCopies - 1})
          .eq('id', bookId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully borrowed "$title"')),
      );
      _fetchBooks(); // Refresh the list
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error borrowing book: ${error.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title or author...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _fetchBooks();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _searchBooks,
            ),
          ),
          
          // Books List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _books.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_books, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No books found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _books.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final book = _books[index];
                          final isAvailable = book['available_copies'] > 0;
                          
                          return Card(
                            margin: const EdgeInsets.all(8),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.menu_book, size: 40, color: Colors.blue.shade700),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              book['title'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            Text(
                                              'by ${book['author']}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Available: ${book['available_copies']}/${book['total_copies']}',
                                          style: TextStyle(
                                            color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: isAvailable
                                            ? () => _borrowBook(
                                                book['id'],
                                                book['title'],
                                                book['available_copies'],
                                              )
                                            : null,
                                        icon: const Icon(Icons.bookmark_add),
                                        label: const Text('Borrow'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isAvailable ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBook,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}