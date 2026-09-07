import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../widgets/app_asset_icon.dart';

part 'app_icon_assets.dart';

abstract final class AppIcons {
  // Provider branding keeps its recognizable silhouette.
  static const apple = PhosphorIconsFill.appleLogo;
  // Primary navigation.
  static const home = PhosphorIconsBold.houseSimple;
  static const collections = PhosphorIconsBold.stack;
  static const interests = PhosphorIconsBold.circlesThreePlus;
  static const search = PhosphorIconsBold.magnifyingGlass;

  // Glimpse features.
  static const rediscover = PhosphorIconsBold.clockCounterClockwise;
  static const termMentioned = PhosphorIconsBold.bookOpenText;
  static const addLink = PhosphorIconsBold.link;
  static const addToCollection = PhosphorIconsBold.folderSimplePlus;
  static const notifications = PhosphorIconsBold.bell;
  static const settings = PhosphorIconsBold.gearSix;

  // Settings destinations.
  static const appearance = PhosphorIconsBold.palette;
  static const language = PhosphorIconsBold.translate;
  static const musicProvider = PhosphorIconsBold.headphones;
  static const privacy = PhosphorIconsBold.shieldCheck;
  static const backup = PhosphorIconsBold.archive;
  static const clearData = PhosphorIconsBold.trashSimple;
  static const about = PhosphorIconsBold.info;
  static const logout = PhosphorIconsBold.signOut;
  static const deleteAccount = PhosphorIconsBold.userMinus;
  static const smartNotifications = notifications;
  static const automaticTheme = PhosphorIconsBold.circleHalfTilt;
  static const lightTheme = PhosphorIconsBold.sun;
  static const darkTheme = PhosphorIconsBold.moon;
  static const amoledTheme = PhosphorIconsBold.circleHalf;
  static const terms = PhosphorIconsBold.scroll;
  static const help = PhosphorIconsBold.question;
  static const feedback = PhosphorIconsBold.envelopeSimple;
  static const rate = PhosphorIconsBold.star;

  // Shared interface actions and onboarding illustrations.
  static const hierarchy = PhosphorIconsBold.treeStructure;
  static const arrowBack = PhosphorIconsBold.arrowLeft;
  static const arrowForward = PhosphorIconsBold.arrowRight;
  static const sparkle = PhosphorIconsBold.sparkle;
  static const bookmarkAdd = PhosphorIconsBold.listPlus;
  static const bookmark = PhosphorIconsBold.bookmarkSimple;
  static const calendar = PhosphorIconsBold.calendarBlank;
  static const checkCircle = PhosphorIconsBold.checkCircle;
  static const check = PhosphorIconsBold.check;
  static const close = PhosphorIconsBold.x;
  static const copy = PhosphorIconsBold.copy;
  static const externalLink = PhosphorIconsBold.arrowSquareOut;
  static const addNote = PhosphorIconsBold.notePencil;
  static const image = PhosphorIconsBold.image;
  static const share = PhosphorIconsBold.shareNetwork;
  static const link = PhosphorIconsBold.linkSimple;
  static const more = PhosphorIconsBold.dotsThreeVertical;
  static const menu = PhosphorIconsBold.list;
  static const tag = PhosphorIconsBold.tag;
  static const text = PhosphorIconsBold.textAlignLeft;
  static const tap = PhosphorIconsBold.handTap;
  static const visibility = PhosphorIconsBold.eye;

  // Shared controls and content metadata use Bold weight.
  static const bank = PhosphorIconsBold.bank;
  static const wallet = PhosphorIconsBold.wallet;
  static const addCircle = PhosphorIconsBold.plusCircle;
  static const route = PhosphorIconsBold.path;
  static const add = PhosphorIconsBold.plus;
  static const cartAdd = PhosphorIconsBold.shoppingCartSimple;
  static const album = PhosphorIconsBold.vinylRecord;
  static const infinity = PhosphorIconsBold.infinity;
  static const apps = PhosphorIconsBold.squaresFour;
  static const architecture = PhosphorIconsBold.compassTool;
  static const arrowUp = PhosphorIconsBold.arrowUp;
  static const article = PhosphorIconsBold.article;
  static const discover = PhosphorIconsBold.squaresFour;
  static const magicWand = PhosphorIconsBold.magicWand;
  static const bookOpen = PhosphorIconsBold.bookOpen;
  static const blocked = PhosphorIconsBold.prohibit;
  static const book = PhosphorIconsBold.book;
  static const bookmarkSaved = PhosphorIconsFill.bookmarkSimple;
  static const brush = PhosphorIconsBold.paintBrush;
  static const campaign = PhosphorIconsBold.megaphone;
  static const category = PhosphorIconsBold.shapes;
  static const celebrate = PhosphorIconsBold.confetti;
  static const recenter = PhosphorIconsBold.crosshair;
  static const chat = PhosphorIconsBold.chatCircle;
  static const checklist = PhosphorIconsBold.listChecks;
  static const clothing = PhosphorIconsBold.coatHanger;
  static const chevronRight = PhosphorIconsBold.caretRight;
  static const circle = PhosphorIconsBold.circle;
  static const cloudOff = PhosphorIconsBold.cloudSlash;
  static const code = PhosphorIconsBold.code;
  static const compare = PhosphorIconsBold.arrowsLeftRight;
  static const computer = PhosphorIconsBold.desktop;
  static const paste = PhosphorIconsBold.clipboardText;
  static const edit = PhosphorIconsBold.pencilSimple;
  static const deleteForever = PhosphorIconsBold.trash;
  static const document = PhosphorIconsBold.fileText;
  static const design = PhosphorIconsBold.pencilRuler;
  static const gem = PhosphorIconsBold.diamond;
  static const checks = PhosphorIconsBold.checks;
  static const dragHandle = PhosphorIconsBold.equals;
  static const dragDots = PhosphorIconsBold.dotsSixVertical;
  static const moveToCollection = PhosphorIconsBold.folderOpen;
  static const error = PhosphorIconsBold.warningCircle;
  static const calendarCheck = PhosphorIconsBold.calendarCheck;
  static const chevronDown = PhosphorIconsBold.caretDown;
  static const explore = PhosphorIconsBold.compass;
  static const heart = PhosphorIconsBold.heart;
  static const filter = PhosphorIconsBold.funnelSimple;
  static const flight = PhosphorIconsBold.airplane;
  static const takeoff = PhosphorIconsBold.airplaneTakeoff;
  static const folderOff = PhosphorIconsBold.folderSimpleDashed;
  static const folder = PhosphorIconsBold.folderSimple;
  static const zipFile = PhosphorIconsBold.fileZip;
  static const forest = PhosphorIconsBold.tree;
  static const numberedList = PhosphorIconsBold.listNumbers;
  static const quote = PhosphorIconsBold.quotes;
  static const legal = PhosphorIconsBold.gavel;
  static const grid = PhosphorIconsBold.squaresFour;
  static const people = PhosphorIconsBold.users;
  static const tools = PhosphorIconsBold.wrench;
  static const history = PhosphorIconsBold.clockCountdown;
  static const buildings = PhosphorIconsBold.buildings;
  static const hourglass = PhosphorIconsBold.hourglass;
  static const inbox = PhosphorIconsBold.tray;
  static const command = PhosphorIconsBold.command;
  static const globe = PhosphorIconsBold.globe;
  static const library = PhosphorIconsBold.books;
  static const idea = PhosphorIconsBold.lightbulb;
  static const linkOff = PhosphorIconsBold.linkBreak;
  static const fire = PhosphorIconsBold.fire;
  static const placeOff = PhosphorIconsBold.mapPinLine;
  static const place = PhosphorIconsBold.mapPin;
  static const lockedClock = PhosphorIconsBold.clockCountdown;
  static const lock = PhosphorIconsBold.lockSimple;
  static const research = PhosphorIconsBold.magnifyingGlass;
  static const map = PhosphorIconsBold.mapTrifold;
  static const read = PhosphorIconsBold.bookOpen;
  static const unread = PhosphorIconsBold.book;
  static const merge = PhosphorIconsBold.gitMerge;
  static const learning = PhosphorIconsBold.brain;
  static const moreHorizontal = PhosphorIconsBold.dotsThree;
  static const movie = PhosphorIconsBold.filmSlate;
  static const music = PhosphorIconsBold.musicNotes;
  static const network = PhosphorIconsBold.speedometer;
  static const news = PhosphorIconsBold.newspaper;
  static const arrowUpRight = PhosphorIconsBold.arrowUpRight;
  static const arrowUpLeft = PhosphorIconsBold.arrowUpLeft;
  static const camera = PhosphorIconsBold.camera;
  static const play = PhosphorIconsBold.playCircle;
  static const listAdd = PhosphorIconsBold.listPlus;
  static const listPlay = PhosphorIconsBold.playlist;
  static const listRemove = PhosphorIconsBold.listDashes;
  static const brain = PhosphorIconsBold.brain;
  static const pin = PhosphorIconsBold.pushPin;
  static const conversation = PhosphorIconsBold.chats;
  static const radioSelected = PhosphorIconsBold.radioButton;
  static const radioUnselected = PhosphorIconsBold.circle;
  static const refresh = PhosphorIconsBold.arrowClockwise;
  static const removeCircle = PhosphorIconsBold.minusCircle;
  static const food = PhosphorIconsBold.forkKnife;
  static const rocket = PhosphorIconsBold.rocketLaunch;
  static const clock = PhosphorIconsBold.clock;
  static const education = PhosphorIconsBold.graduationCap;
  static const science = PhosphorIconsBold.flask;
  static const searchEmpty = PhosphorIconsBold.magnifyingGlassMinus;
  static const selectAll = PhosphorIconsBold.selectionAll;
  static const send = PhosphorIconsBold.paperPlaneTilt;
  static const shield = PhosphorIconsBold.shield;
  static const shoppingBag = PhosphorIconsBold.shoppingBag;
  static const basket = PhosphorIconsBold.basket;
  static const cart = PhosphorIconsBold.shoppingCartSimple;
  static const robot = PhosphorIconsBold.robot;
  static const sortAlphabetical = PhosphorIconsBold.sortAscending;
  static const sort = PhosphorIconsBold.sortDescending;
  static const bowl = PhosphorIconsBold.bowlFood;
  static const game = PhosphorIconsBold.gameController;
  static const sports = PhosphorIconsBold.trophy;
  static const football = PhosphorIconsBold.soccerBall;
  static const note = PhosphorIconsBold.note;
  static const swapHorizontal = PhosphorIconsBold.arrowsLeftRight;
  static const sortDirection = PhosphorIconsBold.arrowsDownUp;
  static const sync = PhosphorIconsBold.arrowsClockwise;
  static const complete = PhosphorIconsBold.checkCircle;
  static const terminal = PhosphorIconsBold.terminalWindow;
  static const mountains = PhosphorIconsBold.mountains;
  static const dislike = PhosphorIconsBold.thumbsDown;
  static const timer = PhosphorIconsBold.timer;
  static const topic = PhosphorIconsBold.folders;
  static const explorePlaces = PhosphorIconsBold.globeHemisphereWest;
  static const trendUp = PhosphorIconsBold.trendUp;
  static const adjust = PhosphorIconsBold.slidersHorizontal;
  static const verified = PhosphorIconsBold.sealCheck;
  static const moveToTop = PhosphorIconsBold.arrowLineUp;
  static const video = PhosphorIconsBold.videoCamera;
  static const kanban = PhosphorIconsBold.kanban;
  static const list = PhosphorIconsBold.list;
  static const visibilityOff = PhosphorIconsBold.eyeSlash;
  static const offline = PhosphorIconsBold.wifiSlash;
  static const work = PhosphorIconsBold.briefcase;
  static const premium = PhosphorIconsBold.medal;

  // Filled variants serve selected states and content badges.
  static const pinFilled = PhosphorIconsFill.pushPin;
  static const bookmarkFilled = PhosphorIconsFill.bookmarkSimple;
  static const cartFilled = PhosphorIconsFill.shoppingCartSimple;
  static const circleFilled = PhosphorIconsFill.circle;

  static final _filledVariants = <IconData, IconData>{
    pin: pinFilled,
    bookmark: bookmarkFilled,
    bookmarkAdd: PhosphorIconsFill.listPlus,
    read: PhosphorIconsFill.bookOpen,
    unread: PhosphorIconsFill.book,
    sparkle: PhosphorIconsFill.sparkle,
    share: PhosphorIconsFill.shareNetwork,
    blocked: PhosphorIconsFill.prohibit,
    home: PhosphorIconsFill.houseSimple,
    collections: PhosphorIconsFill.stack,
    interests: PhosphorIconsFill.circlesThreePlus,
    search: PhosphorIconsFill.magnifyingGlass,
    notifications: PhosphorIconsFill.bell,
    settings: PhosphorIconsFill.gearSix,
    addToCollection: PhosphorIconsFill.folderSimplePlus,
    appearance: PhosphorIconsFill.palette,
    language: PhosphorIconsFill.translate,
    musicProvider: PhosphorIconsFill.headphones,
    privacy: PhosphorIconsFill.shieldCheck,
    backup: PhosphorIconsFill.archive,
    clearData: PhosphorIconsFill.trashSimple,
    about: PhosphorIconsFill.info,
    logout: PhosphorIconsFill.signOut,
    deleteAccount: PhosphorIconsFill.userMinus,
    automaticTheme: PhosphorIconsFill.circleHalfTilt,
    lightTheme: PhosphorIconsFill.sun,
    darkTheme: PhosphorIconsFill.moon,
    amoledTheme: PhosphorIconsFill.circleHalf,
    terms: PhosphorIconsFill.scroll,
    help: PhosphorIconsFill.question,
    feedback: PhosphorIconsFill.envelopeSimple,
    rate: PhosphorIconsFill.star,
    calendar: PhosphorIconsFill.calendarBlank,
    document: PhosphorIconsFill.fileText,
    heart: PhosphorIconsFill.heart,
    game: PhosphorIconsFill.gameController,
    place: PhosphorIconsFill.mapPin,
    wallet: PhosphorIconsFill.wallet,
    termMentioned: PhosphorIconsFill.bookOpenText,
    quote: PhosphorIconsFill.quotes,
    idea: PhosphorIconsFill.lightbulb,
    globe: PhosphorIconsFill.globe,
    album: PhosphorIconsFill.vinylRecord,

    // Filled content badges share the same silhouettes as their outline tokens.
    takeoff: PhosphorIconsFill.airplaneTakeoff,
    article: PhosphorIconsFill.article,
    PhosphorIconsBold.bicycle: PhosphorIconsFill.bicycle,
    PhosphorIconsBold.bowlFood: PhosphorIconsFill.bowlFood,
    brain: PhosphorIconsFill.brain,
    work: PhosphorIconsFill.briefcase,
    buildings: PhosphorIconsFill.buildings,
    PhosphorIconsBold.camera: PhosphorIconsFill.camera,
    PhosphorIconsBold.checkSquare: PhosphorIconsFill.checkSquare,
    code: PhosphorIconsFill.code,
    PhosphorIconsBold.columns: PhosphorIconsFill.columns,
    PhosphorIconsBold.cpu: PhosphorIconsFill.cpu,
    movie: PhosphorIconsFill.filmSlate,
    science: PhosphorIconsFill.flask,
    topic: PhosphorIconsFill.folders,
    food: PhosphorIconsFill.forkKnife,
    legal: PhosphorIconsFill.gavel,
    explorePlaces: PhosphorIconsFill.globeHemisphereWest,
    education: PhosphorIconsFill.graduationCap,
    PhosphorIconsBold.leaf: PhosphorIconsFill.leaf,
    checklist: PhosphorIconsFill.listChecks,
    mountains: PhosphorIconsFill.mountains,
    music: PhosphorIconsFill.musicNotes,
    PhosphorIconsBold.pawPrint: PhosphorIconsFill.pawPrint,
    PhosphorIconsBold.planet: PhosphorIconsFill.planet,
    rocket: PhosphorIconsFill.rocketLaunch,
    PhosphorIconsBold.shapes: PhosphorIconsFill.shapes,
    shield: PhosphorIconsFill.shield,
    shoppingBag: PhosphorIconsFill.shoppingBag,
    football: PhosphorIconsFill.soccerBall,
    apps: PhosphorIconsFill.squaresFour,
    PhosphorIconsBold.steeringWheel: PhosphorIconsFill.steeringWheel,
    PhosphorIconsBold.tShirt: PhosphorIconsFill.tShirt,
    hierarchy: PhosphorIconsFill.treeStructure,
    PhosphorIconsBold.trendUp: PhosphorIconsFill.trendUp,
    people: PhosphorIconsFill.users,
    PhosphorIconsBold.wrench: PhosphorIconsFill.wrench,
  };

  static IconData filledVariant(IconData icon) {
    return _filledVariants[icon] ?? icon;
  }

  static String? assetVariant(IconData icon, {bool active = false}) {
    final pair = _appIconAssets[icon];
    return pair == null ? null : (active ? pair.$2 : pair.$1);
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.color,
    this.size,
    this.filled = false,
    this.selected = false,
    this.semanticLabel,
  }) : assert(
         icon == null || icon is PhosphorIconData,
         'AppIcon only supports icons from phosphor_flutter.',
       );

  final IconData? icon;
  final Color? color;
  final double? size;
  final bool filled;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    if (glyph == null) {
      return Icon(null, size: size, color: color, semanticLabel: semanticLabel);
    }
    final active = selected || filled;
    final asset = AppIcons.assetVariant(glyph, active: active);
    if (asset != null) {
      return AppAssetIcon(
        asset,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
      );
    }
    return Icon(
      active ? AppIcons.filledVariant(glyph) : glyph,
      color: color,
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}

/// Adapts the shared renderer for Material APIs that require an [Icon].
class AppMaterialIcon extends Icon {
  const AppMaterialIcon(
    super.icon, {
    super.key,
    super.size,
    super.color,
    super.semanticLabel,
  });

  @override
  Widget build(BuildContext context) =>
      AppIcon(icon, size: size, color: color, semanticLabel: semanticLabel);
}
