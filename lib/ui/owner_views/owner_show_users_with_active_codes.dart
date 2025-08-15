import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/owner_providers/owner_activate_code_with_users_provider.dart';
import 'package:toplansin/ui/user_views/dialogs/show_styled_confirm_dialog.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';

class OwnerShowUsersWithActiveCodes extends StatefulWidget {
  final String haliSahaId;

  const OwnerShowUsersWithActiveCodes({
    Key? key,
    required this.haliSahaId,
  }) : super(key: key);

  @override
  State<OwnerShowUsersWithActiveCodes> createState() => _OwnerShowUsersWithActiveCodesState();
}

class _OwnerShowUsersWithActiveCodesState extends State<OwnerShowUsersWithActiveCodes> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final prov = context.read<OwnerActivateCodeWithUsersProvider>();
      prov.fetchUsersByActiveCode(widget.haliSahaId, context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<OwnerActivateCodeWithUsersProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildUserList(prov)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 12),
      decoration:  BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondaryDark, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Koda Sahip Kullanıcılar',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Kullanıcı ara...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
    );
  }

  Widget _buildUserList(OwnerActivateCodeWithUsersProvider prov) {
    if (prov.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (prov.users.isEmpty) {
      return Center(
        child: Text(
          'Koda sahip kullanıcı bulunamadı.',
          style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary),
        ),
      );
    }

    final filtered = prov.users.where((u) {
      return u.name.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filtered.length,
      itemBuilder: (_, i) =>
          _buildUserCard(
            userId: filtered[i].id,
            name: filtered[i].name,
            email: filtered[i].email,
            phone: filtered[i].phone ?? '',
          ),
    );
  }

  Widget _buildUserCard({
    required String userId,
    required String name,
    required String email,
    required String phone,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: AppColors.primary.withOpacity(0.15),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              AppColors.surfaceDark.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              vertical: 12, horizontal: 16),
          leading: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondary, width: 2),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.secondary,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
            ),
          ),
          title: Text(
            name,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    email,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary),
                  ),
                ),
              if (phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    phone,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
          trailing: IconButton(onPressed: () async {
            final confirm =
            await ShowStyledConfirmDialog.show(
              context,
              title: "Kullanıcıyı kaldır",
              message:
              "Onaylarsanız halı saha kodunuz bu kullanıcının hesabından silenecek onaylıyor musunuz?",
            );
            if (confirm == true) {
              await Provider.of<OwnerActivateCodeWithUsersProvider>(context, listen: false)
                  .deleteUsersByActivateCode(
                userId,
                widget.haliSahaId,
                context,
              );
            }
          }, icon: Icon(Icons.delete_outline)),
        ),
      ),
    );
  }
}
