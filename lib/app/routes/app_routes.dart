// ignore_for_file: constant_identifier_names

part of 'app_pages.dart';
// DO NOT EDIT. This is code generated via package:get_cli/get_cli.dart

abstract class Routes {
  Routes._();
  static const HOME = _Paths.HOME;
  static const INTRODUCTION = _Paths.INTRODUCTION;
  static const SPLASH = _Paths.SPLASH;
  static const LOGIN = _Paths.LOGIN;
  static const ATTENDANCE = _Paths.ATTENDANCE;
  static const PERMIT = _Paths.PERMIT;
  static const PERMIT_LIST = _Paths.PERMIT_LIST;
  static const PERMIT_SHOW = _Paths.PERMIT_SHOW;
  static const PERMIT_CREATE = _Paths.PERMIT_CREATE;
  static const NOTIFICATION = _Paths.NOTIFICATION;
  static const ATTENDANCE_LIST = _Paths.ATTENDANCE + _Paths.ATTENDANCE_LIST;
  static const ANNOUNCEMENT = _Paths.HOME + _Paths.ANNOUNCEMENT;
  static const ANNOUNCEMENT_DETAIL =
      _Paths.HOME + _Paths.ANNOUNCEMENT + _Paths.ANNOUNCEMENT_DETAIL;
  static const ACTIVITY = _Paths.HOME + _Paths.ACTIVITY;
}

abstract class _Paths {
  _Paths._();
  static const HOME = '/home';
  static const INTRODUCTION = '/introduction';
  static const SPLASH = '/splash';
  static const LOGIN = '/login';
  static const ATTENDANCE = '/attendance';
  static const ATTENDANCE_LIST = '/list';
  static const PERMIT = '/permit';
  static const PERMIT_LIST = '/permit/list';
  static const PERMIT_SHOW = '/permit/show';
  static const PERMIT_CREATE = '/permit/create';
  static const NOTIFICATION = '/notification';
  static const ANNOUNCEMENT = '/announcement';
  static const ANNOUNCEMENT_DETAIL = '/detail';
  static const ACTIVITY = '/activity';
}
