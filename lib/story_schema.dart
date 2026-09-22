import 'package:flutter/material.dart';

enum StoryEntryType { myStory, personaFeed }

class StoryEntrySchema {
  final String id;
  final String title;
  final StoryEntryType type;
  final IconData icon;
  final List<String> personaStoryIds;

  const StoryEntrySchema({
    required this.id,
    required this.title,
    required this.type,
    required this.icon,
    this.personaStoryIds = const [],
  });
}

class PersonaStorySchema {
  final String id;
  final String personaName;
  final String coverImagePath;
  final String previewText;

  const PersonaStorySchema({
    required this.id,
    required this.personaName,
    required this.coverImagePath,
    required this.previewText,
  });
}

const List<StoryEntrySchema> storyEntries = [
  StoryEntrySchema(
    id: 'my_story',
    title: '내 스토리',
    type: StoryEntryType.myStory,
    icon: Icons.person,
  ),
  StoryEntrySchema(
    id: 'empathy_friend',
    title: '공감 친구',
    type: StoryEntryType.personaFeed,
    icon: Icons.favorite_border,
    personaStoryIds: ['hayeon_story', 'naeun_story'],
  ),
  StoryEntrySchema(
    id: 'growth_coach',
    title: '성장 코치',
    type: StoryEntryType.personaFeed,
    icon: Icons.fitness_center,
    personaStoryIds: ['suyeon_story', 'hayeon_story'],
  ),
  StoryEntrySchema(
    id: 'creative_feed',
    title: '크리에이티브',
    type: StoryEntryType.personaFeed,
    icon: Icons.lightbulb_outline,
    personaStoryIds: ['jieun_story', 'hayeon_story'],
  ),
];

const List<PersonaStorySchema> personaStories = [
  PersonaStorySchema(
    id: 'hayeon_story',
    personaName: '하연',
    coverImagePath: 'images/Hayeon/Cafe.jpg',
    previewText: '감성 카페 스토리 초안',
  ),
  PersonaStorySchema(
    id: 'suyeon_story',
    personaName: '수연',
    coverImagePath: 'images/Suyeon/Suyeon_health.jpg',
    previewText: '운동 루틴 스토리 초안',
  ),
  PersonaStorySchema(
    id: 'jieun_story',
    personaName: '지은',
    coverImagePath: 'images/Jiun/Jiun_produce.jpg',
    previewText: '크리에이터 인사이트 초안',
  ),
  PersonaStorySchema(
    id: 'naeun_story',
    personaName: '나은',
    coverImagePath: 'images/Naeun/Naeun_book.jpg',
    previewText: '심야 감성 스토리 초안',
  ),
];

List<PersonaStorySchema> resolvePersonaStories(StoryEntrySchema entry) {
  return personaStories
      .where((story) => entry.personaStoryIds.contains(story.id))
      .toList();
}
