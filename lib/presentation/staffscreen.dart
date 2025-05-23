import 'package:flutter/material.dart';

// Dummy Data Model for Staff
class Staff {
  final String name;
  final String userId;
  final String password;
  // Map of company name to canEdit permission
  final Map<String, bool> companyPermissions;

  Staff({
    required this.name,
    required this.userId,
    required this.password,
    required this.companyPermissions,
  });
}

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  // Dummy staff list
  List<Staff> staffList = [
    Staff(
      name: "Alice Smith",
      userId: "alice01",
      password: "pass123",
      companyPermissions: {
        "Company A": true,
        "Company B": false,
        "Company C": true,
      },
    ),
    Staff(
      name: "Bob Johnson",
      userId: "bob02",
      password: "bobpass",
      companyPermissions: {
        "Company A": false,
        "Company B": true,
        "Company C": true,
      },
    ),
  ];

  // Dummy companies
  List<String> allCompanies = ["Company A", "Company B", "Company C"];

  void _showStaffDetail(Staff staff) {
    // For selecting companies
    List<String> selectedCompanies = staff.companyPermissions.keys.toList();
    // For canEdit toggles (initialize from staff data)
    Map<String, bool> canEditMap = Map<String, bool>.from(staff.companyPermissions);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      Text(
                        "Staff Details",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      Text("Name: ${staff.name}", style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 10),
                      Text("User ID: ${staff.userId}", style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 10),
                      Text("Password: ${staff.password}", style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        "Select Companies & Permissions",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...allCompanies.map((company) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selectedCompanies.contains(company),
                          title: Row(
                            children: [
                              Expanded(child: Text(company)),
                              if (selectedCompanies.contains(company))
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "Can Edit",
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    Switch(
                                      value: canEditMap[company] ?? false,
                                      onChanged: (val) {
                                        setModalState(() {
                                          canEditMap[company] = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          onChanged: (bool? selected) {
                            setModalState(() {
                              if (selected == true) {
                                if (!selectedCompanies.contains(company)) {
                                  selectedCompanies.add(company);
                                  canEditMap[company] = false; // default to false
                                }
                              } else {
                                selectedCompanies.remove(company);
                                canEditMap.remove(company);
                              }
                            });
                          },
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text("Close"),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _addStaff() async {
    // Dummy add staff logic, you may replace with a real form/dialog
    TextEditingController nameController = TextEditingController();
    TextEditingController userIdController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        List<String> selectedCompanies = [];
        Map<String, bool> canEditMap = {};
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: "Name"),
                      ),
                      TextField(
                        controller: userIdController,
                        decoration: const InputDecoration(labelText: "User ID"),
                      ),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: "Password"),
                        obscureText: true,
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Select Companies & Permissions",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...allCompanies.map((company) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selectedCompanies.contains(company),
                          title: Row(
                            children: [
                              Expanded(child: Text(company)),
                              if (selectedCompanies.contains(company))
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "Can Edit",
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    Switch(
                                      value: canEditMap[company] ?? false,
                                      onChanged: (val) {
                                        setModalState(() {
                                          canEditMap[company] = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          onChanged: (bool? selected) {
                            setModalState(() {
                              if (selected == true) {
                                if (!selectedCompanies.contains(company)) {
                                  selectedCompanies.add(company);
                                  canEditMap[company] = false;
                                }
                              } else {
                                selectedCompanies.remove(company);
                                canEditMap.remove(company);
                              }
                            });
                          },
                        );
                      }).toList(),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () => Navigator.pop(context),
                          ),
                          ElevatedButton(
                            child: const Text("Add Staff"),
                            onPressed: () {
                              if (nameController.text.isEmpty ||
                                  userIdController.text.isEmpty ||
                                  passwordController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Fill all fields")),
                                );
                                return;
                              }
                              Map<String, bool> selectedPermissions = {};
                              for (final c in selectedCompanies) {
                                selectedPermissions[c] = canEditMap[c] ?? false;
                              }
                              setState(() {
                                staffList.add(
                                  Staff(
                                    name: nameController.text,
                                    userId: userIdController.text,
                                    password: passwordController.text,
                                    companyPermissions: selectedPermissions,
                                  ),
                                );
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff"),
        leading: const BackButton(),
      ),
      body: ListView.builder(
        itemCount: staffList.length,
        itemBuilder: (context, idx) {
          final staff = staffList[idx];
          return ListTile(
            leading: CircleAvatar(
              child: Text(staff.name.isNotEmpty ? staff.name[0] : "?"),
            ),
            title: Text(staff.name),
            subtitle: Text("UserID: ${staff.userId}"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showStaffDetail(staff),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add Staff"),
              onPressed: _addStaff,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}