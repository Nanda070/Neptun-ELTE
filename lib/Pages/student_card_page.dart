import 'package:flutter/material.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';
import '../storage.dart' as storage;

/// Plan item 12 — claim status + bank flags + optional profile.
/// No decorative QR, no invented card number / expiry.
class StudentCardPage extends StatefulWidget {
  const StudentCardPage({super.key});

  @override
  State<StudentCardPage> createState() => _StudentCardPageState();
}

class _StudentCardPageState extends State<StudentCardPage> {
  StudentCardSnapshot? _snap;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = StudentCardRequest.loadCached();
    if (cached != null && mounted) {
      setState(() {
        _snap = cached;
        _loading = false;
      });
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    if (!storage.DataCache.getIsModernApi()) {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _refreshing = _snap != null;
        if (_snap == null) _loading = true;
      });
    }
    try {
      final fresh = await StudentCardRequest.fetchAndCache();
      if (!mounted) return;
      setState(() {
        _snap = fresh;
        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  String _dash(String? v) {
    if (v == null || v.trim().isEmpty) {
      return AppStrings.getLanguagePack().studentCard_EmptyValue;
    }
    return v.trim();
  }

  String _yesNo(bool v) {
    final lp = AppStrings.getLanguagePack();
    return v ? lp.studentCard_Yes : lp.studentCard_No;
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.getTheme().secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: AppColors.getTheme().secondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.getTheme().textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = AppStrings.getLanguagePack();
    final snap = _snap;

    return Scaffold(
      backgroundColor: AppColors.getTheme().rootBackground,
      appBar: AppBar(
        backgroundColor: AppColors.getTheme().rootBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.getTheme().textColor),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          lp.studentCard_Title,
          style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_refreshing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.getTheme().secondary,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.getTheme().textColor),
              onPressed: () {
                AppHaptics.lightImpact();
                _refresh();
              },
            ),
        ],
      ),
      body: _loading && snap == null
          ? Center(
              child: CircularProgressIndicator(color: AppColors.getTheme().secondary),
            )
          : RefreshIndicator(
              color: AppColors.getTheme().secondary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _card([
                    Text(
                      lp.studentCard_NoQrNote,
                      style: TextStyle(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.75),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    if (snap?.fromCache == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        lp.cache_showingFromCache,
                        style: TextStyle(
                          color: AppColors.getTheme().secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ]),

                  _sectionHeader(lp.studentCard_ClaimSection, Icons.badge_outlined),
                  if (snap?.claim == null || snap!.claim!.isEmpty)
                    _card([
                      Text(
                        lp.studentCard_NoClaim,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ])
                  else
                    _card([
                      _row(lp.studentCard_ClaimType, _dash(snap.claim!.claimType)),
                      _row(lp.studentCard_FirStatus, _dash(
                        snap.claim!.firStatus.isNotEmpty
                            ? snap.claim!.firStatus
                            : snap.claim!.firStatusId,
                      )),
                      _row(lp.studentCard_ProcessStatus, _dash(snap.claim!.processStatus)),
                      _row(lp.studentCard_FinalDecision, _dash(snap.claim!.finalDecision)),
                      _row(lp.studentCard_RegistrationDate, _dash(snap.claim!.registrationDate)),
                      _row(lp.studentCard_Training, _dash(snap.claim!.trainingName)),
                      _row(lp.studentCard_Faculty, _dash(snap.claim!.trainingFaculty)),
                      _row(
                        lp.studentCard_Institute,
                        _dash(
                          [
                            snap.claim!.primaryInstituteName,
                            if (snap.claim!.primaryInstitutePrintCode.isNotEmpty)
                              '(${snap.claim!.primaryInstitutePrintCode})',
                          ].where((s) => s.isNotEmpty).join(' '),
                        ),
                      ),
                    ]),

                  if (snap != null && snap.addresses.isNotEmpty) ...[
                    _sectionHeader(lp.studentCard_AddressSection, Icons.home_outlined),
                    ...snap.addresses.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _card([
                          if (a.addressType.isNotEmpty)
                            _row(lp.studentCard_AddressType, a.addressType),
                          _row(lp.studentCard_Address, _dash(a.address)),
                        ]),
                      ),
                    ),
                  ],

                  _sectionHeader(lp.studentCard_BankSection, Icons.account_balance_outlined),
                  if (snap == null || snap.banks.isEmpty)
                    _card([
                      Text(
                        lp.studentCard_NoBank,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ])
                  else
                    ...snap.banks.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _card([
                          _row(lp.studentCard_Owner, _dash(b.owner)),
                          _row(lp.studentCard_BankName, _dash(b.bankName)),
                          _row(lp.studentCard_Default, _yesNo(b.isDefault)),
                          _row(lp.studentCard_Foreign, _yesNo(b.isForeign)),
                          _row(lp.studentCard_Valid, _yesNo(b.isValid)),
                          if (b.otpStatusIsVisible && b.otpStatus.isNotEmpty)
                            _row(lp.studentCard_OtpStatus, b.otpStatus),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              lp.studentCard_BankPrivacyNote,
                              style: TextStyle(
                                color: AppColors.getTheme().textColor.withValues(alpha: 0.45),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),

                  _sectionHeader(lp.studentCard_ProfileSection, Icons.person_outline_rounded),
                  if (snap?.profile == null)
                    _card([
                      Text(
                        lp.studentCard_NoProfile,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ])
                  else ...[
                    _card([
                      _row(lp.studentCard_PrintName, _dash(snap!.profile!.printName)),
                      _row(lp.studentCard_Honorific, _dash(snap.profile!.title)),
                      _row(lp.studentCard_LastName, _dash(snap.profile!.lastName)),
                      _row(lp.studentCard_FirstName, _dash(snap.profile!.firstName)),
                      _row(lp.studentCard_LoginName, _dash(snap.profile!.loginName)),
                      _row(lp.studentCard_BornName, _dash(snap.profile!.bornName)),
                      _row(lp.studentCard_BornDate, _dash(snap.profile!.bornDate)),
                      _row(lp.studentCard_BornPlace, _dash(snap.profile!.bornPlace)),
                      _row(lp.studentCard_BornCountry, _dash(snap.profile!.bornCountry)),
                      _row(lp.studentCard_Sex, _dash(snap.profile!.sex)),
                      _row(lp.studentCard_MotherName, _dash(snap.profile!.motherName)),
                      _row(lp.studentCard_Children, _dash(snap.profile!.numberOfChildren)),
                      _row(lp.studentCard_EduId, _dash(snap.profile!.educationalIdentifier)),
                      if (snap.profile!.citizenships.isNotEmpty)
                        _row(
                          lp.studentCard_Citizenship,
                          snap.profile!.citizenships.join(', '),
                        ),
                    ]),
                    if (snap.profile!.extraFields.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _card([
                        for (final e in snap.profile!.extraFields)
                          _row(
                            e.translation.isNotEmpty
                                ? e.translation
                                : (e.field.isNotEmpty ? e.field : lp.studentCard_ExtraField),
                            _dash(e.value),
                          ),
                      ]),
                    ],
                  ],

                  if (snap?.contacts != null) ...[
                    _sectionHeader(lp.studentCard_ContactsSection, Icons.contact_mail_outlined),
                    _card([
                      if (snap!.contacts!.emails.isNotEmpty)
                        _row(lp.studentCard_Emails, snap.contacts!.emails.join('\n')),
                      if (snap.contacts!.phones.isNotEmpty)
                        _row(lp.studentCard_Phones, snap.contacts!.phones.join('\n')),
                      if (snap.contacts!.addresses.isNotEmpty)
                        _row(lp.studentCard_Address, snap.contacts!.addresses.join('\n')),
                      if (snap.contacts!.emails.isEmpty &&
                          snap.contacts!.phones.isEmpty &&
                          snap.contacts!.addresses.isEmpty)
                        Text(
                          lp.studentCard_EmptyValue,
                          style: TextStyle(
                            color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
    );
  }
}
