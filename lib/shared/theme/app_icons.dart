import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

abstract final class AppIcons {
  // Primary navigation.
  static const home = PhosphorIconsRegular.houseSimple;
  static const collections = PhosphorIconsRegular.cardsThree;
  static const interests = PhosphorIconsRegular.circlesThreePlus;
  static const search = PhosphorIconsRegular.magnifyingGlass;

  // Glimpse features.
  static const rediscover = PhosphorIconsRegular.clockCounterClockwise;
  static const termMentioned = PhosphorIconsRegular.bookOpenText;
  static const addLink = PhosphorIconsRegular.linkSimple;
  static const addToCollection = PhosphorIconsRegular.folderSimplePlus;
  static const notifications = PhosphorIconsRegular.bellRinging;
  static const settings = PhosphorIconsRegular.gearSix;

  // Settings destinations.
  static const appearance = PhosphorIconsRegular.palette;
  static const privacy = PhosphorIconsRegular.shieldCheck;
  static const backup = PhosphorIconsRegular.cloudArrowUp;
  static const clearData = PhosphorIconsRegular.trashSimple;
  static const about = PhosphorIconsRegular.info;
  static const logout = PhosphorIconsRegular.signOut;
  static const deleteAccount = PhosphorIconsRegular.userMinus;
  static const smartNotifications = notifications;
  static const automaticTheme = PhosphorIconsRegular.circleHalfTilt;
  static const lightTheme = PhosphorIconsRegular.sun;
  static const darkTheme = PhosphorIconsRegular.moon;
  static const amoledTheme = PhosphorIconsRegular.circleHalf;
  static const terms = PhosphorIconsRegular.scroll;
  static const help = PhosphorIconsRegular.question;

  // Shared interface actions and onboarding illustrations.
  static const hierarchy = PhosphorIconsRegular.treeStructure;
  static const arrowBack = PhosphorIconsRegular.arrowLeft;
  static const arrowForward = PhosphorIconsRegular.arrowRight;
  static const sparkle = PhosphorIconsRegular.sparkle;
  static const bookmarkAdd = PhosphorIconsRegular.bookmarkSimple;
  static const bookmark = PhosphorIconsRegular.bookmarkSimple;
  static const calendar = PhosphorIconsRegular.calendarBlank;
  static const checkCircle = PhosphorIconsRegular.checkCircle;
  static const check = PhosphorIconsRegular.check;
  static const close = PhosphorIconsRegular.x;
  static const copy = PhosphorIconsRegular.copy;
  static const image = PhosphorIconsRegular.image;
  static const share = PhosphorIconsRegular.shareNetwork;
  static const link = PhosphorIconsRegular.link;
  static const more = PhosphorIconsRegular.dotsThreeVertical;
  static const tag = PhosphorIconsRegular.tag;
  static const text = PhosphorIconsRegular.textAlignLeft;
  static const tap = PhosphorIconsRegular.handTap;
  static const visibility = PhosphorIconsRegular.eye;

  static final _selectedVariants = <IconData, IconData>{
    home: PhosphorIconsFill.houseSimple,
    collections: PhosphorIconsFill.cardsThree,
    interests: PhosphorIconsFill.circlesThreePlus,
    search: PhosphorIconsFill.magnifyingGlass,
  };

  static IconData selectedVariant(IconData icon) {
    return _selectedVariants[icon] ?? icon;
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.color,
    this.size,
    this.selected = false,
    this.semanticLabel,
  }) : assert(
         icon is PhosphorIconData,
         'AppIcon only supports icons from phosphor_flutter.',
       );

  final IconData icon;
  final Color? color;
  final double? size;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      selected ? AppIcons.selectedVariant(icon) : icon,
      color: color,
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}
