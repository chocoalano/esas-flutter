/// Where the home feature's screens live in the route table.
///
/// Two shapes, because GetX needs both. The full paths are what you navigate
/// to; the `…Segment` values are what a nested `GetPage` is *named*, relative
/// to its parent. Deriving one from the other is why the pair is here rather
/// than duplicated in the page table.
class HomeRoutes {
  const HomeRoutes._();

  static const home = '/home';
  static const announcement = '$home$announcementSegment';
  static const announcementDetail = '$announcement$announcementDetailSegment';
  static const activity = '$home$activitySegment';

  static const announcementSegment = '/announcement';
  static const announcementDetailSegment = '/detail';
  static const activitySegment = '/activity';
}
