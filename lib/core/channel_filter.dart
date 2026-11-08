import 'constants.dart';
import '../data/models/channel.dart';

/// Shared helpers for filtering the channel list. Kept pure so both the mobile
/// home screen and the desktop shell behave identically.
class ChannelFilter {
  ChannelFilter._();

  /// Effective group after accounting for the adult-section visibility toggle.
  static String effectiveGroup(String group, bool showAdult) {
    if (group == 'All') return 'All';
    if (!showAdult && group == AppConfig.adultGroup) return 'All';
    return group;
  }

  /// Groups visible given the adult-section toggle.
  static List<String> visibleGroups(List<String> groups, bool showAdult) {
    return groups
        .where((group) => showAdult || group != AppConfig.adultGroup)
        .toList(growable: false);
  }

  /// Filters [channels] by the adult toggle, selected [group] and search [query].
  static List<Channel> filter(
    List<Channel> channels, {
    required String query,
    required String group,
    required bool showAdult,
  }) {
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    final effective = effectiveGroup(group, showAdult);

    return channels
        .where((channel) {
          if (!showAdult && channel.group == AppConfig.adultGroup) return false;
          if (effective != 'All' && channel.group != effective) return false;
          if (tokens.isNotEmpty &&
              !tokens.every((token) => channel.searchHaystack.contains(token))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }
}