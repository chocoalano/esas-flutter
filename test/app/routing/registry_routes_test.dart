import 'package:esas/app/routing/app_pages.dart';
import 'package:esas/core/registry/module_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// CORE-06 (and HOME-07). The service registry advertised `/mtms/work-orders`,
/// which no page answers, and `/permit-list`, which is spelled `/permit/list`
/// in the route table. With no `unknownRoute`, GetX 4.7.2 null-checks the
/// missing page and the tile does nothing.
void main() {
  Set<String> registered() {
    final paths = <String>{};

    void walk(List<GetPage> pages, String prefix) {
      for (final page in pages) {
        final path = '$prefix${page.name}';
        paths.add(path);
        walk(page.children, path);
      }
    }

    walk(AppPages.routes, '');
    return paths;
  }

  test('every service the registry advertises opens a registered page', () {
    final paths = registered();

    for (final service in ModuleRegistry.allServices) {
      expect(
        paths,
        contains(service.route),
        reason: '${service.id} points at ${service.route}',
      );
    }
  });

  test('an unknown route has somewhere to land', () {
    expect(AppPages.unknownRoute, isNotNull);
    expect(registered(), isNot(contains(AppPages.unknownRoute.name)));
  });
}
