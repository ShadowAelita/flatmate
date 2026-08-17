class WGMember {
  final String id;
  final String name;

  const WGMember({required this.id, required this.name});
}

class WGData {
  static final List<WGMember> members = [];
  static final List<Map<String, dynamic>> shoppingItems = [];
  static final List<Map<String, dynamic>> tasks = [];

  static String? currentMemberId;

  static WGMember? get currentMember {
    if (currentMemberId == null) {
      return null;
    }

    for (final member in members) {
      if (member.id == currentMemberId) {
        return member;
      }
    }

    return null;
  }

  static int get currentMemberTaskCount {
    final member = currentMember;

    if (member == null) {
      return 0;
    }

    return tasks.where((task) {
      return task['assignedTo'] == member.id && task['completed'] == false;
    }).length;
  }
}
