// lib/features/hr/screens/hr_employee_details.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kleenops_admin/app/shared_widgets/navigation/details_appbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_navbar_adapter.dart';
import 'package:kleenops_admin/app/shared_widgets/navigation/home_appbar_adapter.dart';
import 'package:kleenops_admin/features/hr/details/hr_employee_standard_rates.dart';
import 'package:kleenops_admin/features/hr/screens/hr_roles.dart';
import 'package:kleenops_admin/theme/palette.dart';
import 'package:shared_widgets/containers/canvas_top_bookend.dart';
import 'package:shared_widgets/containers/standard_canvas.dart';
import 'package:shared_widgets/drawers/menu_drawer.dart';
import 'package:kleenops_admin/app/routes.dart';
import 'package:kleenops_admin/features/hr/forms/hr_garnishment_form.dart';
import 'package:kleenops_admin/features/hr/widgets/benefit_eligibility_badge.dart';
import 'package:shared_widgets/tabs/standard_tab.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/hr/utils/member_file_images.dart';

class HrEmployeesDetailsScreen extends ConsumerWidget {
  final String documentId;
  final String imageUrl;
  final String name;
  final String roleName;

  factory HrEmployeesDetailsScreen.fromExtra(Map<String, dynamic>? extra) {
    final e = extra ?? {};
    return HrEmployeesDetailsScreen(
      documentId: e['documentId'] as String? ?? '',
      imageUrl: e['currentImageUrl'] as String? ?? '',
      name: e['currentName'] as String? ?? '',
      roleName: e['currentRoleName'] as String? ?? '',
    );
  }

  const HrEmployeesDetailsScreen({
    super.key,
    required this.documentId,
    required this.imageUrl,
    required this.name,
    required this.roleName,
  });

  Widget _wrapCanvas(Widget child) {
    return StandardCanvas(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CanvasTopBookend(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPaletteScope.of(context);
    final bool hideChrome = false;
    Widget buildBottomBar() {
      if (hideChrome) return const SizedBox.shrink();
      final menuSections = MenuDrawerSections(
        actions: [
          ContentMenuItem(
            icon: Icons.attach_money,
            label: 'Standard Rates',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HrEmployeeStandardRatesScreen(),
                ),
              );
            },
          ),
          ContentMenuItem(
            icon: Icons.badge_outlined,
            label: 'Roles',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HrRolesScreen(),
                ),
              );
            },
          ),
        ],
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailsAppBar(
            title: name,
            menuSections: menuSections,
          ),
          const HomeNavBarAdapter(highlightSelected: false),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          return buildBottomBar();
        },
      ),
      body: _wrapCanvas(
          ref.watch(companyIdProvider).when(
                data: (companyRef) {
                  if (companyRef == null) {
                    return const Center(child: Text('No company'));
                  }
                  return _EmployeeDetailsBody(
                    companyRef: companyRef,
                    documentId: documentId,
                    name: name,
                    roleName: roleName,
                    hideChrome: hideChrome,
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
        ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: palette.primary1.withAlpha(220),
        tooltip: 'Edit Employee',
        child: const Icon(Icons.edit),
        onPressed: () {
          ref.read(companyIdProvider).whenData((companyRef) async {
            final resolvedImageUrl = companyRef == null
                ? ''
                : await MemberFileImages.primaryProfileImageUrl(
                    companyRef: companyRef,
                    memberId: documentId,
                  );
            if (!context.mounted) return;
            context.push(
              '/hr/employeeEdit',
              extra: {
                'documentId': documentId,
                'currentName': name,
                'currentRoleName': roleName,
                'currentImageUrl': resolvedImageUrl,
              },
            );
          });
        },
      ),
    );
  }
}

// ─────────────────────── Body with Firestore stream ───────────────────────

class _EmployeeDetailsBody extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> companyRef;
  final String documentId;
  final String name;
  final String roleName;
  final bool hideChrome;

  const _EmployeeDetailsBody({
    required this.companyRef,
    required this.documentId,
    required this.name,
    required this.roleName,
    required this.hideChrome,
  });

  @override
  Widget build(BuildContext context) {
    final memberStream =
        FirebaseFirestore.instance.collection('member').doc(documentId).snapshots();
    final imageFuture = MemberFileImages.primaryProfileImageUrl(
      companyRef: companyRef,
      memberId: documentId,
    );

    return FutureBuilder<String>(
      future: imageFuture,
      builder: (context, imageSnap) {
        final resolvedImageUrl = imageSnap.data?.trim() ?? '';

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: memberStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data?.data() ?? {};

            return _EmployeeDetailsTabs(
              data: data,
              imageUrl: resolvedImageUrl,
              name: name,
              roleName: roleName,
              hideChrome: hideChrome,
              companyRef: companyRef,
              memberId: documentId,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────── Tabbed detail view ───────────────────────────

class _EmployeeDetailsTabs extends StatelessWidget {
  final Map<String, dynamic> data;
  final String imageUrl;
  final String name;
  final String roleName;
  final bool hideChrome;
  final DocumentReference<Map<String, dynamic>>? companyRef;
  final String? memberId;

  const _EmployeeDetailsTabs({
    required this.data,
    required this.imageUrl,
    required this.name,
    required this.roleName,
    required this.hideChrome,
    this.companyRef,
    this.memberId,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          // ── Header: avatar + name ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[300],
                  child: ClipOval(
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (c, u) =>
                                const CircularProgressIndicator(),
                            errorWidget: (c, u, e) =>
                                const Icon(Icons.error, size: 30),
                          )
                        : Image.asset(
                            'assets/logo.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (roleName.isNotEmpty)
                        Text(
                          roleName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      _buildStatusChip(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tabs ──
          Container(
            color: Colors.white,
            child: StandardTabBar(
              isScrollable: true,
              dividerColor: Colors.grey[300],
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3.0,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Employment'),
                Tab(text: 'Pay & Tax'),
                Tab(text: 'Banking'),
                Tab(text: 'Benefits'),
                Tab(text: 'Documents'),
              ],
            ),
          ),

          // ── Tab content ──
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildOverviewTab(context),
                _buildEmploymentTab(context),
                _buildPayTaxTab(context),
                _buildBankingTab(context),
                _buildBenefitsTab(context),
                _buildDocumentsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final active = data['active'] ?? true;
    final employmentType = (data['employmentType'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: active ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? Colors.green[300]! : Colors.red[300]!,
              ),
            ),
            child: Text(
              active ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                color: active ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (employmentType.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                _formatEmploymentType(employmentType),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatEmploymentType(String type) {
    switch (type) {
      case 'full-time':
        return 'Full-Time';
      case 'part-time':
        return 'Part-Time';
      case 'contractor':
        return 'Contractor';
      default:
        return type;
    }
  }

  // ─────────────────── TAB: Overview ───────────────────

  Widget _buildOverviewTab(BuildContext context) {
    final bottomInset = hideChrome
        ? 16.0
        : kBottomNavigationBarHeight + 16.0 +
            MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact
          _detailSection('Contact', [
            _detailRow(Icons.email_outlined, 'Email',
                data['email']?.toString() ?? '—'),
            _detailRow(Icons.phone_outlined, 'Phone',
                data['phone']?.toString() ?? '—'),
          ]),

          // Date of birth
          if (data['dateOfBirth'] is Timestamp)
            _detailSection('Personal', [
              _detailRow(
                Icons.cake_outlined,
                'Date of Birth',
                DateFormat('yMMMd')
                    .format((data['dateOfBirth'] as Timestamp).toDate()),
              ),
            ]),

          // Address
          if (data['address'] is Map) ...[
            _detailSection('Address', [
              _detailRow(
                Icons.location_on_outlined,
                'Address',
                _formatAddress(data['address'] as Map),
              ),
            ]),
          ],

          // Emergency Contact
          if (data['emergencyContact'] is Map) ...[
            _detailSection('Emergency Contact', [
              _detailRow(
                Icons.emergency_outlined,
                'Name',
                (data['emergencyContact'] as Map)['name']?.toString() ?? '—',
              ),
              _detailRow(
                Icons.phone_outlined,
                'Phone',
                (data['emergencyContact'] as Map)['phone']?.toString() ?? '—',
              ),
              _detailRow(
                Icons.people_outline,
                'Relationship',
                (data['emergencyContact'] as Map)['relationship']?.toString() ??
                    '—',
              ),
            ]),
          ],

          // Notes
          if ((data['notes'] ?? '').toString().isNotEmpty)
            _detailSection('Notes', [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  data['notes'].toString(),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ]),
        ],
      ),
    );
  }

  // ─────────────────── TAB: Employment ─────────────────

  Widget _buildEmploymentTab(BuildContext context) {
    final bottomInset = hideChrome
        ? 16.0
        : kBottomNavigationBarHeight + 16.0 +
            MediaQuery.of(context).padding.bottom;

    final startDate = data['startDate'];
    final hireDate = startDate is Timestamp
        ? DateFormat('yMMMd').format(startDate.toDate())
        : '—';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailSection('Classification', [
            _detailRow(Icons.work_outline, 'Employment Type',
                _formatEmploymentType(data['employmentType']?.toString() ?? '')),
            _detailRow(Icons.assignment_ind_outlined, 'Classification',
                (data['classification'] ?? 'w2').toString().toUpperCase()),
            _detailRow(Icons.gavel_outlined, 'FLSA Status',
                _formatExemptStatus(data['exemptStatus']?.toString() ?? '')),
          ]),

          _detailSection('Work Location', [
            _detailRow(Icons.location_city_outlined, 'Work State',
                data['workState']?.toString() ?? '—'),
          ]),

          _detailSection('Role & Dates', [
            _detailRow(Icons.badge_outlined, 'Role', roleName),
            _detailRow(Icons.calendar_today_outlined, 'Start Date', hireDate),
          ]),
        ],
      ),
    );
  }

  String _formatExemptStatus(String status) {
    switch (status) {
      case 'exempt':
        return 'Exempt';
      case 'non-exempt':
        return 'Non-Exempt';
      default:
        return status;
    }
  }

  // ─────────────────── TAB: Pay & Tax ──────────────────

  Widget _buildPayTaxTab(BuildContext context) {
    final bottomInset = hideChrome
        ? 16.0
        : kBottomNavigationBarHeight + 16.0 +
            MediaQuery.of(context).padding.bottom;

    final payRate = data['payRate'];
    final payType = (data['payType'] ?? 'hourly').toString();
    final payFrequency = (data['payFrequency'] ?? '').toString();
    final overtimeEligible = data['overtimeEligible'] ?? false;
    final overtimeRate = data['overtimeRate'];

    final rateLabel = payType == 'salary' ? 'Annual Salary' : 'Hourly Rate';
    final rateDisplay = payRate != null
        ? '\$${NumberFormat('#,##0.00').format(payRate)}'
        : '—';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailSection('Compensation', [
            _detailRow(Icons.attach_money, rateLabel, rateDisplay),
            _detailRow(Icons.payments_outlined, 'Pay Type',
                payType == 'salary' ? 'Salary' : 'Hourly'),
            if (payFrequency.isNotEmpty)
              _detailRow(Icons.schedule_outlined, 'Pay Frequency',
                  _formatPayFrequency(payFrequency)),
            _detailRow(
              Icons.access_time,
              'Overtime Eligible',
              overtimeEligible ? 'Yes' : 'No',
            ),
            if (overtimeEligible && overtimeRate != null)
              _detailRow(Icons.trending_up, 'Overtime Multiplier',
                  '${overtimeRate}x'),
          ]),

          _detailSection('Federal Tax (W-4)', [
            _detailRow(Icons.account_balance_outlined, 'Filing Status',
                _formatFilingStatus(data['federalFilingStatus']?.toString() ?? '')),
            _detailRow(Icons.people_outline, 'Allowances',
                (data['federalAllowances'] ?? 0).toString()),
            if ((data['additionalFederalWithholding'] ?? 0) > 0)
              _detailRow(Icons.add_circle_outline, 'Additional Withholding',
                  '\$${data['additionalFederalWithholding']}'),
          ]),

          if ((data['workState'] ?? '').toString().isNotEmpty)
            _detailSection('State Tax (${data['workState']})', [
              _detailRow(Icons.people_outline, 'State Allowances',
                  (data['stateAllowances'] ?? 0).toString()),
              if ((data['additionalStateWithholding'] ?? 0) > 0)
                _detailRow(Icons.add_circle_outline, 'Additional Withholding',
                    '\$${data['additionalStateWithholding']}'),
            ]),
        ],
      ),
    );
  }

  String _formatPayFrequency(String freq) {
    switch (freq) {
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Bi-Weekly';
      case 'semimonthly':
        return 'Semi-Monthly';
      case 'monthly':
        return 'Monthly';
      default:
        return freq;
    }
  }

  String _formatFilingStatus(String status) {
    switch (status) {
      case 'single':
        return 'Single';
      case 'married':
        return 'Married Filing Jointly';
      case 'head_of_household':
        return 'Head of Household';
      default:
        return status;
    }
  }

  // ─────────────────── TAB: Banking ────────────────────

  Widget _buildBankingTab(BuildContext context) {
    final bottomInset = hideChrome
        ? 16.0
        : kBottomNavigationBarHeight + 16.0 +
            MediaQuery.of(context).padding.bottom;

    final paymentMethod = (data['paymentMethod'] ?? 'direct_deposit').toString();
    final banks = data['bankAccounts'];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailSection('Payment Method', [
            _detailRow(
              paymentMethod == 'direct_deposit'
                  ? Icons.account_balance_outlined
                  : Icons.print,
              'Method',
              paymentMethod == 'direct_deposit'
                  ? 'Direct Deposit'
                  : 'Paper Check',
            ),
          ]),

          if (paymentMethod == 'direct_deposit' &&
              banks is List &&
              banks.isNotEmpty)
            ...banks.asMap().entries.map((entry) {
              final bank = entry.value as Map<String, dynamic>;
              final accountNum = (bank['accountNumber'] ?? '').toString();
              final masked = accountNum.length > 4
                  ? '****${accountNum.substring(accountNum.length - 4)}'
                  : accountNum;

              return _detailSection('Bank Account', [
                _detailRow(Icons.account_balance, 'Bank',
                    bank['bankName']?.toString() ?? '—'),
                _detailRow(Icons.tag, 'Account', masked),
                _detailRow(
                  Icons.category_outlined,
                  'Type',
                  (bank['accountType'] ?? '').toString() == 'savings'
                      ? 'Savings'
                      : 'Checking',
                ),
              ]);
            }),

          if (paymentMethod == 'direct_deposit' &&
              (banks == null || (banks is List && banks.isEmpty)))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                border: Border.all(color: Colors.amber[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Direct deposit is selected but no bank account has been configured. Edit employee to add bank details.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────── TAB: Benefits ────────────────────

  Widget _buildBenefitsTab(BuildContext context) {
    final bottomInset = hideChrome
        ? 16.0
        : kBottomNavigationBarHeight + 16.0 +
            MediaQuery.of(context).padding.bottom;

    if (companyRef == null || memberId == null) {
      return Center(
        child: Text('Unable to load benefits',
            style: TextStyle(color: Colors.grey[500])),
      );
    }

    final enrollmentStream = companyRef!
        .collection('benefitEnrollment')
        .where('memberId', isEqualTo: memberId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: enrollmentStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Eligibility badge
              _detailSection('Eligibility', [
                Row(
                  children: [
                    BenefitEligibilityBadge(
                      employmentType:
                          (data['employmentType'] ?? 'full-time').toString(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatEmploymentType(
                          data['employmentType']?.toString() ?? ''),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ]),

              // Active enrollments
              if (docs.isEmpty)
                _detailSection('Enrollments', [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'No benefit enrollments yet.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ])
              else
                _detailSection(
                    'Enrollments (${docs.length})',
                    docs.map((doc) {
                      final d = doc.data();
                      final planName =
                          (d['benefitPlanName'] ?? 'Unknown Plan').toString();
                      final status = (d['status'] ?? '').toString();
                      final eeCost = d['employeeContribution'];
                      final erCost = d['employerContribution'];

                      final isActive = status == 'active';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: isActive
                                  ? Colors.green[600]
                                  : Colors.grey[400],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(planName,
                                      style: const TextStyle(fontSize: 14)),
                                  Text(
                                    [
                                      _capitalize(status),
                                      if (eeCost != null)
                                        'EE: \$$eeCost',
                                      if (erCost != null)
                                        'ER: \$$erCost',
                                    ].join(' · '),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList()),

              // Enroll button
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutePaths.hrBenefitEnrollmentForm,
                    extra: {'memberId': memberId},
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Enroll in Plan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // ─────────────────── TAB: Documents ──────────────────

  Widget _buildDocumentsTab(BuildContext context) {
    final bottomInset = hideChrome
        ? 16.0
        : kBottomNavigationBarHeight + 16.0 +
            MediaQuery.of(context).padding.bottom;

    final w4OnFile = data['w4OnFile'] ?? false;
    final i9Verified = data['i9Verified'] ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailSection('Compliance Documents', [
            _documentRow('W-4 Federal Tax Form', w4OnFile,
                date: data['w4Date']),
            _documentRow('I-9 Employment Verification', i9Verified,
                date: data['i9VerifiedDate']),
          ]),

          // ── Wage Garnishments ──
          _detailSection(
            'Wage Garnishments',
            _buildGarnishmentList(),
          ),

          // Add garnishment button
          const SizedBox(height: 8),
          if (companyRef != null && memberId != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HrGarnishmentForm(
                        companyRef: companyRef!,
                        memberId: memberId!,
                        memberName: name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Garnishment'),
              ),
            ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Additional employee documents can be managed from the HR Documents section.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGarnishmentList() {
    final garnishments = data['garnishments'] as List<dynamic>? ?? [];
    if (garnishments.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'No wage garnishments.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ),
      ];
    }
    return garnishments.asMap().entries.map((entry) {
      final g = entry.value as Map<String, dynamic>;
      final type = (g['type'] ?? '').toString();
      final amount = g['amount'];
      final amountType = (g['amountType'] ?? 'fixed').toString();
      final active = g['active'] ?? false;
      final payee = (g['payee'] ?? '').toString();

      final amountStr = amountType == 'percentage'
          ? '${amount ?? 0}% of disposable income'
          : '\$${amount ?? 0} per pay period';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              active ? Icons.gavel : Icons.gavel_outlined,
              size: 18,
              color: active ? Colors.red[600] : Colors.grey[400],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatGarnishmentType(type),
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    [amountStr, if (payee.isNotEmpty) payee]
                        .join(' · '),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: active ? Colors.red[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? Colors.red[300]! : Colors.grey[300]!,
                ),
              ),
              child: Text(
                active ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 11,
                  color: active ? Colors.red[800] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatGarnishmentType(String type) {
    switch (type) {
      case 'child_support': return 'Child Support';
      case 'tax_levy': return 'Tax Levy';
      case 'creditor': return 'Creditor Garnishment';
      case 'student_loan': return 'Student Loan';
      case 'bankruptcy': return 'Bankruptcy';
      default: return 'Garnishment';
    }
  }

  // ─────────────────── Shared helpers ──────────────────

  Widget _detailSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentRow(String title, bool onFile, {dynamic date}) {
    final dateStr = date is Timestamp
        ? DateFormat('yMMMd').format(date.toDate())
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            onFile ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: onFile ? Colors.green[600] : Colors.grey[400],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                if (dateStr != null)
                  Text(
                    'Completed $dateStr',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: onFile ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: onFile ? Colors.green[300]! : Colors.orange[300]!,
              ),
            ),
            child: Text(
              onFile ? 'On File' : 'Pending',
              style: TextStyle(
                fontSize: 11,
                color: onFile ? Colors.green[800] : Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAddress(Map addr) {
    final parts = <String>[];
    final street = (addr['street'] ?? '').toString();
    final city = (addr['city'] ?? '').toString();
    final state = (addr['state'] ?? '').toString();
    final zip = (addr['zip'] ?? '').toString();
    if (street.isNotEmpty) parts.add(street);
    final cityStateZip = [city, state].where((s) => s.isNotEmpty).join(', ');
    if (cityStateZip.isNotEmpty || zip.isNotEmpty) {
      parts.add([cityStateZip, zip].where((s) => s.isNotEmpty).join(' '));
    }
    return parts.isNotEmpty ? parts.join('\n') : '—';
  }
}
