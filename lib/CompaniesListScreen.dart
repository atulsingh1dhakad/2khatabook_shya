import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CompaniesListScreen extends StatefulWidget {
  const CompaniesListScreen({Key? key}) : super(key: key);

  @override
  State<CompaniesListScreen> createState() => _CompaniesListScreenState();
}

class _CompaniesListScreenState extends State<CompaniesListScreen> {
  List<dynamic> companies = [];
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    fetchCompanies();
  }

  Future<void> fetchCompanies() async {
    const String url = "http://account.galaxyex.xyz/v1/user/api//account/get-company";
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? authKey = prefs.getString("auth_token");

      if (authKey == null) {
        setState(() {
          errorMsg = "No authentication token found. Please log in again.";
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authkey": authKey, // Use "Authorization" if your API expects that
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['meta']?['status'] == true && data['data'] is List) {
          setState(() {
            companies = data['data'];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMsg = "Failed to fetch company data!";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMsg = "Failed to fetch companies: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = "Error fetching companies: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Companies List")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg != null
          ? Center(child: Text(errorMsg!))
          : ListView.builder(
        itemCount: companies.length,
        itemBuilder: (context, index) {
          final company = companies[index];
          return ListTile(
            leading: const Icon(Icons.business),
            title: Text(company['companyName'] ?? "No Name"),
            subtitle: Text("ID: ${company['companyId'] ?? ""}"),
          );
        },
      ),
    );
  }
}