import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easypark_desktop/models/user_model.dart';
import 'package:easypark_desktop/providers/user_provider.dart';
import 'package:easypark_desktop/providers/base_provider.dart';
import 'package:http/http.dart' as http;
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/utils/error_message.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UserProvider _userProvider = UserProvider();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<User> _users = [];
  bool _isLoading = true;
  bool? _activeFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final filter = <String, dynamic>{};
      if (_activeFilter != null) {
        filter['isActive'] = _activeFilter;
      }
      if (_searchQuery.trim().isNotEmpty) {
        filter['fts'] = _searchQuery.trim();
      }
      final result = await _userProvider.get(filter: filter);
      if (mounted) {
        setState(() {
          _users = result.result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: ${normalizeErrorMessage(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _toggleActive(User user) async {
    try {
      final url = '${BaseProvider.baseUrl}User/${user.id}/status';
      final uri = Uri.parse(url);
      final headers = _userProvider.createHeaders();
      final response = await http.patch(
        uri,
        headers: headers,
        body: jsonEncode({'isActive': !user.isActive}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                user.isActive
                    ? '${user.firstName} deactivated'
                    : '${user.firstName} activated',
              ),
              backgroundColor: user.isActive ? EasyParkColors.accent : EasyParkColors.success,
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(httpFailureMessage(
            action: 'User status update',
            statusCode: response.statusCode,
            body: response.body,
          )),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update user status: ${normalizeErrorMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          SizedBox(
            width: 280,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: EasyParkColors.onAccent),
                decoration: InputDecoration(
                  hintText: 'Search name/username/email...',
                  hintStyle: const TextStyle(color: EasyParkColors.onAccent),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: EasyParkColors.onAccent,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: EasyParkColors.onAccent,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadUsers();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: EasyParkColors.accent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                ),
                onSubmitted: (value) {
                  setState(() => _searchQuery = value);
                  _loadUsers();
                },
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: EasyParkColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<bool?>(
                value: _activeFilter,
                hint: const Text(
                  'All Users',
                  style: TextStyle(color: EasyParkColors.onAccent),
                ),
                dropdownColor: EasyParkColors.surfaceElevated,
                iconEnabledColor: EasyParkColors.onAccent,
                style: const TextStyle(color: EasyParkColors.onAccent),
                items: const [
                  DropdownMenuItem<bool?>(
                    value: null,
                    child: Text(
                      'All Users',
                      style: TextStyle(color: EasyParkColors.onAccent),
                    ),
                  ),
                  DropdownMenuItem<bool?>(
                    value: true,
                    child: Text(
                      'Active Only',
                      style: TextStyle(color: EasyParkColors.onAccent),
                    ),
                  ),
                  DropdownMenuItem<bool?>(
                    value: false,
                    child: Text(
                      'Inactive Only',
                      style: TextStyle(color: EasyParkColors.onAccent),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _activeFilter = val);
                  _loadUsers();
                },
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: EasyParkColors.muted),
                  SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(color: EasyParkColors.muted, fontSize: 18),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Username')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Registered')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _users.map((user) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text('${user.firstName} ${user.lastName}'),
                              ),
                              DataCell(Text(user.username)),
                              DataCell(Text(user.email)),
                              DataCell(Text(user.phone ?? '—')),
                              DataCell(
                                Text(
                                  '${user.createdAt.day}.${user.createdAt.month}.${user.createdAt.year}',
                                ),
                              ),
                              DataCell(Text(user.roles.join(', '))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: user.isActive
                                        ? EasyParkColors.success.withValues(alpha: 0.15)
                                        : EasyParkColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    user.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: user.isActive
                                          ? EasyParkColors.successOnContainer
                                          : EasyParkColors.errorOnContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: Icon(
                                    user.isActive
                                        ? Icons.block
                                        : Icons.check_circle_outline,
                                    color: user.isActive
                                        ? EasyParkColors.accent
                                        : EasyParkColors.success,
                                  ),
                                  tooltip: user.isActive
                                      ? 'Deactivate user'
                                      : 'Activate user',
                                  onPressed: () => _toggleActive(user),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
