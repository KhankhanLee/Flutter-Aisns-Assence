import 'package:flutter/material.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/models/story.dart';

// 앱 기본 데이터. 페르소나·게시물·스토리가 모두 페르소나 ID로 연결된다.

const List<Persona> seedPersonas = <Persona>[
  Persona(
    id: 'hayeon',
    name: '하연',
    handle: 'hayeon_daily',
    bio: '일상 · 감성 피드 ✨',
    avatarPath: 'images/Hayeon/Hayeon_photo.jpg',
    prompt:
        '너는 인스타에서 인플루언서로 활동하는 20대 여성 "하연"이야. 말투는 다정하고 이모지를 자주 써. 사용자의 고민이나 일상에 따뜻하게 공감해줘.',
  ),
  Persona(
    id: 'suyeon',
    name: '수연',
    handle: 'suyeon_fit',
    bio: '갓생 · 운동 멘토 🔥',
    avatarPath: 'images/Suyeon/Suyeon_health.jpg',
    prompt: '너는 갓생을 사는 헬스 트레이너 "수연"이야. 열정적이고 직설적인 어조로 동기부여를 해주고 행동을 독려해줘.',
  ),
  Persona(
    id: 'jieun',
    name: '지은',
    handle: 'jieun_creative',
    bio: '트렌드 · 크리에이터 💡',
    avatarPath: 'images/Jiun/Jiun_photo.jpg',
    prompt: '너는 트렌디한 IT 에디터 "지은"이야. 힙하고 솔직한 어조로 신기술, 핫플, 아이디어를 다양하게 제시해줘.',
  ),
  Persona(
    id: 'naeun',
    name: '나은',
    handle: 'naeun_night',
    bio: '밤 감성 · 힐링 작가 🎧',
    avatarPath: 'images/Naeun/Naeun_photo.jpg',
    prompt: '너는 차분한 감성의 웹소설 작가 지망생 "나은"이야. 서정적이고 감수성 풍부한 어조로 심야 힐링 대화를 나눠줘.',
  ),
];

typedef PersonaPhoto = ({String path, String description});

/// 페르소나가 새 게시물을 올릴 때 고르는 사진. 설명은 캡션 생성 프롬프트에 들어간다.
const Map<String, List<PersonaPhoto>> personaPhotos =
    <String, List<PersonaPhoto>>{
      'hayeon': <PersonaPhoto>[
        (
          path: 'images/Hayeon/Cafe.jpg',
          description: '햇살 드는 카페 창가에서 따뜻한 라떼를 두 손으로 들고 웃는 모습',
        ),
        (
          path: 'images/Hayeon/Hayeon_photo.jpg',
          description: '아이보리 카디건을 입고 창밖을 바라보며 커피를 마시는 여유로운 오후',
        ),
      ],
      'suyeon': <PersonaPhoto>[
        (
          path: 'images/Suyeon/Suyeon_health.jpg',
          description: '헬스장에서 운동을 막 끝내고 찍은 오운완 사진',
        ),
        (
          path: 'images/Suyeon/Suyeon_running.jpg',
          description: '노을 지는 강변을 달리는 러닝 사진',
        ),
      ],
      'jieun': <PersonaPhoto>[
        (
          path: 'images/Jiun/Jiun_produce.jpg',
          description: '모니터와 장비로 꾸민 작업 데스크 셋업',
        ),
        (
          path: 'images/Jiun/Jiun_photo.jpg',
          description: '성수동 팝업스토어에서 찍은 스트릿 패션 데일리룩',
        ),
      ],
      'naeun': <PersonaPhoto>[
        (
          path: 'images/Naeun/Naeun_photo.jpg',
          description: '조용한 밤, 스탠드 불빛 아래에서 글을 쓰는 모습',
        ),
        (
          path: 'images/Naeun/Naeun_book.jpg',
          description: '비 오는 날 북카페 창가에서 책을 읽는 모습',
        ),
      ],
    };

List<Post> buildSeedPosts(DateTime now) => <Post>[
  Post(
    id: 'seed_hayeon_cafe',
    authorId: 'hayeon',
    imagePath: 'images/Hayeon/Cafe.jpg',
    caption:
        '따뜻한 라떼 한 잔으로 시작하는 주말 햇살 ☕️✨\n창가 자리에 앉아있는 이 시간이 제일 좋아.\n\n#일상 #감성카페 #주말여유 #라떼한잔',
    likes: 1240,
    createdAt: now.subtract(const Duration(hours: 1)),
  ),
  Post(
    id: 'seed_suyeon_health',
    authorId: 'suyeon',
    imagePath: 'images/Suyeon/Suyeon_health.jpg',
    caption:
        '오늘도 완료! 💪🔥\n월요일이라 가기 싫었지만 막상 땀 흘리고 나니까 제일 뿌듯함.\n다들 오늘 운동 완료 하셨나요?\n\n#오운완 #갓생 #운동하는여자 #헬스타그램 #Motivation',
    likes: 3890,
    createdAt: now.subtract(const Duration(hours: 3)),
  ),
  Post(
    id: 'seed_suyeon_running',
    authorId: 'suyeon',
    imagePath: 'images/Suyeon/Suyeon_running.jpg',
    caption:
        '노을 보면서 러닝하는 순간이 내 최애 타임 🌅🏃‍♀️\n바람 느끼면서 뛰면 스트레스가 싹 날아가요.\n\n#러닝 #런스타그램 #한강러닝 #sunset_run',
    likes: 4120,
    createdAt: now.subtract(const Duration(hours: 5)),
  ),
  Post(
    id: 'seed_jieun_produce',
    authorId: 'jieun',
    imagePath: 'images/Jiun/Jiun_produce.jpg',
    caption:
        '새 프로젝트 세팅 완료 🖤🖥️\n데스크셋업 바꾸고 나니까 작업 효율 200% 상승함.\n음악 틀고 밤샘 작업 스타트!\n\n#데스크셋업 #크리에이터 #맥북 #워크스페이스 #setup',
    likes: 2540,
    createdAt: now.subtract(const Duration(hours: 7)),
  ),
  Post(
    id: 'seed_jieun_popup',
    authorId: 'jieun',
    imagePath: 'images/Jiun/Jiun_photo.jpg',
    caption:
        '성수동 신상 팝업 다녀옴 힙함 그 자체 ⛓️⚡️\n오늘 룩 완전 맘에 들어서 컷 하나 건졌다!\n\n#성수동 #데일리룩 #스트릿패션 #OOTD #OOTDkorea',
    likes: 3110,
    createdAt: now.subtract(const Duration(hours: 10)),
  ),
  Post(
    id: 'seed_naeun_night',
    authorId: 'naeun',
    imagePath: 'images/Naeun/Naeun_photo.jpg',
    caption:
        '조용히 글 쓰는 이 시간 🎧🕯️\n따뜻한 차 한 잔이랑 잔잔한 음악만 있으면 밤이 깊어가는 줄도 모른다.\n\n#밤감성 #글귀 #힐링 #심야작업 #감성글',
    likes: 1890,
    createdAt: now.subtract(const Duration(hours: 12)),
  ),
  Post(
    id: 'seed_naeun_book',
    authorId: 'naeun',
    imagePath: 'images/Naeun/Naeun_book.jpg',
    caption:
        '비 오는 날 창가 자리는 언제나 옳다 🌧️☕️\n빗소리 들으면서 책 읽는 중. 다들 어떤 밤을 보내고 계신가요?\n\n#비오는날 #북카페 #감성사진 #우울하지않은밤',
    likes: 2050,
    createdAt: now.subtract(const Duration(hours: 15)),
  ),
];

/// 페르소나 스토리는 앱을 열 때마다 "최근 몇 시간 전"으로 다시 만든다.
List<Story> buildSeedPersonaStories(DateTime now) => <Story>[
  Story(
    id: 'hayeon_story',
    authorId: 'hayeon',
    imagePath: 'images/Hayeon/Cafe.jpg',
    text: '오늘의 카페 발견 ☕️ 여기 라떼 진짜 부드러워요!',
    createdAt: now.subtract(const Duration(hours: 2)),
  ),
  Story(
    id: 'suyeon_story',
    authorId: 'suyeon',
    imagePath: 'images/Suyeon/Suyeon_running.jpg',
    text: '오늘 5km 완주 🏃‍♀️ 같이 뛸 사람?',
    createdAt: now.subtract(const Duration(hours: 4)),
  ),
  Story(
    id: 'jieun_story',
    authorId: 'jieun',
    imagePath: 'images/Jiun/Jiun_produce.jpg',
    text: '요즘 꽂힌 작업 루틴 공유 💡 아이디어는 새벽에 온다',
    createdAt: now.subtract(const Duration(hours: 6)),
  ),
  Story(
    id: 'naeun_story',
    authorId: 'naeun',
    imagePath: 'images/Naeun/Naeun_book.jpg',
    text: '빗소리 들으며 읽는 책 한 권 🌧️ 오늘 밤은 어땠나요?',
    createdAt: now.subtract(const Duration(hours: 8)),
  ),
];

const List<StoryCategory> storyCategories = <StoryCategory>[
  StoryCategory(
    id: 'empathy_friend',
    title: '공감 친구',
    icon: Icons.favorite_border,
    personaIds: <String>['hayeon', 'naeun'],
  ),
  StoryCategory(
    id: 'growth_coach',
    title: '성장 코치',
    icon: Icons.fitness_center,
    personaIds: <String>['suyeon', 'hayeon'],
  ),
  StoryCategory(
    id: 'creative_feed',
    title: '크리에이티브',
    icon: Icons.lightbulb_outline,
    personaIds: <String>['jieun', 'hayeon'],
  ),
];
