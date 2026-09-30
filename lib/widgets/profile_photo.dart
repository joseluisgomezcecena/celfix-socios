import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/models/customer.dart';
import '../theme.dart';

/// Avatar del socio: su foto si la subió, o sus iniciales.
class ProfilePhoto extends StatelessWidget {
  final Customer customer;
  final double size;

  /// Muestra el botón de cámara encima. Solo en la pantalla de perfil.
  final VoidCallback? onEdit;

  const ProfilePhoto({
    super.key,
    required this.customer,
    this.size = 96,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final photo = customer.photoUrl;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CelfixColors.blue.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: CelfixShape.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null
          ? Center(
              child: Text(
                customer.initials,
                style: TextStyle(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w600,
                  color: CelfixColors.blue,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: photo,
              fit: BoxFit.cover,
              // Una foto que no carga no debe dejar un hueco: caemos a las
              // iniciales, igual que si no tuviera.
              errorWidget: (context, url, error) => Center(
                child: Text(
                  customer.initials,
                  style: TextStyle(
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w600,
                    color: CelfixColors.blue,
                  ),
                ),
              ),
            ),
    );

    if (onEdit == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Material(
            color: CelfixColors.blue,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.photo_camera, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
