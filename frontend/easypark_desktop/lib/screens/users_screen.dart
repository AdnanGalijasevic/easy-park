import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easypark_desktop/models/user_model.dart';
import 'package:easypark_desktop/providers/user_provider.dart';
import 'package:easypark_desktop/providers/base_provider.dart';
import 'package:http/http.dart' as http;
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UserProvider _userProvider = UserProvider();
  List<User> _users = [];
  bool _isLoading = true;
  bool? _activeFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final filter = _activeFilter != null ? {'isActive': _activeFilter} : null;
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
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  Future<void> _toggleActive(User user) async {
    try {
      final url = '${BaseProvider.baseUrl}User/toggle-active';
      final uri = Uri.parse(url);
      final headers = _userProvider.createHeaders();
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'userId': user.id}),
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
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
