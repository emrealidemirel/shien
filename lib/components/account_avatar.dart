import 'package:flutter/material.dart';
import 'package:medicine_app/services/auth/account_profile_service.dart';
import 'package:medicine_app/services/auth/auth_service.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, this.size = 56});
  final double size;
  @override
  Widget build(BuildContext context) {
    final profile = AccountProfileService.current;
    final auth = AuthService.instance;
    return ListenableBuilder(
      listenable: profile ?? auth,
      builder: (context, _) {
        final colors = Theme.of(context).colorScheme;
        final bytes = profile?.photoBytes;
        final url = profile?.photoUrl;
        final name =
            profile?.displayName ??
            AccountProfileService.providerDisplayName(auth);
        final initials = name
            ?.trim()
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .take(2)
            .map((p) => p.characters.first.toUpperCase())
            .join();
        final fallback = Center(
          child: initials?.isNotEmpty == true
              ? Text(
                  initials!,
                  style: TextStyle(
                    fontSize: size * .32,
                    fontWeight: FontWeight.w700,
                    color: colors.onSecondaryContainer,
                  ),
                )
              : Icon(
                  Icons.person_outline_rounded,
                  size: size * .55,
                  color: colors.onSecondaryContainer,
                ),
        );
        return ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: ColoredBox(
              color: colors.secondaryContainer,
              child: bytes != null
                  ? Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    )
                  : url != null
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : fallback,
                    )
                  : fallback,
            ),
          ),
        );
      },
    );
  }
}
