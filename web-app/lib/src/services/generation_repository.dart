import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/team_user.dart';
import 'public_github_service.dart';

class GenerationOption {
  const GenerationOption({
    required this.id,
    required this.color,
    this.scheduleVisible = true,
    this.memberVisible = true,
  });

  final String id;
  final String color;
  final bool scheduleVisible;
  final bool memberVisible;

  factory GenerationOption.fromJson(Map<String, dynamic> json) =>
      GenerationOption(
        id: json['id']?.toString() ?? '',
        color: json['color']?.toString() ?? '#9E9E9E',
        scheduleVisible: json['scheduleVisible'] != false,
        memberVisible: json['memberVisible'] != false,
      );
}

class GenerationRepository {
  static const _cacheKey = 'member_generations_cache';
  static const defaultOptions = [
    GenerationOption(id: '1기', color: '#E53935'),
    GenerationOption(id: '2기', color: '#FB8C00'),
    GenerationOption(id: '3기', color: '#FBC02D'),
    GenerationOption(id: '4기', color: '#43A047'),
    GenerationOption(id: '기타', color: '#42A5F5'),
    GenerationOption(
      id: 'Guest',
      color: '#9E9E9E',
      scheduleVisible: false,
      memberVisible: false,
    ),
  ];

  Future<List<GenerationOption>> fetchOptions() async {
    try {
      final source = await PublicGithubService().fetchText(
        'remote-data/main.json',
        timeout: const Duration(seconds: 5),
      );
      final config = jsonDecode(source) as Map<String, dynamic>;
      final options =
          (config['generationOptions'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(GenerationOption.fromJson)
              .where((option) => option.id.isNotEmpty)
              .toList();
      return options.isEmpty ? defaultOptions : options;
    } catch (_) {
      return defaultOptions;
    }
  }

  Future<Map<String, List<String>>> fetch({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final source = await PublicGithubService().fetchText(
        'remote-data/generations.json',
        timeout: const Duration(seconds: 5),
      );
      await preferences.setString(_cacheKey, source);
      return decode(source);
    } catch (_) {
      final cached = preferences.getString(_cacheKey);
      if (cached != null && !forceRefresh) return decode(cached);
      rethrow;
    }
  }

  Map<String, List<String>> decode(String source) {
    final body = jsonDecode(source) as Map<String, dynamic>;
    final values = body['generations'] as Map<String, dynamic>? ?? const {};
    return values.map(
      (loginId, generations) => MapEntry(
        loginId.toLowerCase(),
        TeamUser.sortGenerations(
          (generations as List<dynamic>? ?? const []).whereType<String>(),
        ),
      ),
    );
  }
}
