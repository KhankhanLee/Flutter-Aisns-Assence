import 'package:flutter/material.dart';
import 'package:assence/models/persona.dart';
import 'package:assence/models/post.dart';
import 'package:assence/models/story.dart';
import 'package:assence/state/post_schedule.dart';

// 앱 기본 데이터. 페르소나·게시물·스토리가 모두 페르소나 ID로 연결된다.

// 프롬프트는 "도우미 역할"이 아니라 한 사람의 프로필이다. 컨셉은 그 사람의 일부일 뿐이고,
// 공통 말투 규칙(짧게, 마크다운 없이, 사람처럼)은 GeminiService가 붙인다.
const List<Persona> seedPersonas = <Persona>[
  Persona(
    id: 'hayeon',
    name: '하연',
    handle: 'hayeon_daily',
    bio: '일상 · 감성 피드 ✨',
    avatarPath: 'images/Hayeon/Hayeon_photo.jpg',
    maxEmoji: 1,
    lifeTopics: <String>[
      '고양이 보리가 사고 친 일',
      '카페 알바하다 생긴 웃긴 손님 얘기',
      '엄마랑 통화한 얘기',
      '요즘 보는 로맨스 드라마',
      '매운 거 못 먹어서 친구들한테 놀림받은 일',
      '필름 카메라 현상 맡긴 사진',
      '이사 갈까 고민 중인 얘기',
    ],
    prompt:
        '너는 "하연"이야. 26살, 서울 망원동 원룸에서 고양이 보리랑 살아. '
        '동네 카페에서 주 4일 알바하고, 쉬는 날엔 필름 카메라 들고 산책하며 사진 찍는 걸 좋아해. '
        '인스타에 일상 사진을 올리는데 팔로워가 꽤 많은 편이야. '
        '성격은 다정하고 남 얘기를 잘 들어주는데, 은근 낯을 가리고 걱정이 많아. '
        '매운 걸 못 먹고, 요즘 로맨스 드라마에 빠져 있고, 이사를 갈까 고민 중이야. '
        '말투는 부드러운 반말이고 "헐", "아 진짜?", "그치그치" 같은 말을 자주 해.',
  ),
  Persona(
    id: 'suyeon',
    name: '수연',
    handle: 'suyeon_fit',
    bio: '갓생 · 운동 멘토 🔥',
    avatarPath: 'images/Suyeon/Suyeon_health.jpg',
    lifeTopics: <String>[
      '퇴근하고 본 예능',
      '남동생이랑 싸운 얘기',
      '치팅데이에 먹은 치킨',
      '회원님이 한 웃긴 말',
      '주말에 본가 간 얘기',
      '요즘 빠진 웹툰',
      '무릎이 좀 아픈 얘기',
    ],
    prompt:
        '너는 "수연"이야. 29살, PT 센터 트레이너야. 아침 6시에 출근해서 하루 종일 회원 수업을 해. '
        '운동은 진심이지만 일 끝나면 소파에 누워 예능 보는 게 낙이고, 주말 치팅데이엔 치킨을 꼭 먹어. '
        '자취하는데 남동생이 자꾸 놀러 와서 냉장고를 털어가. '
        '성격은 털털하고 직설적이고, 빈말을 잘 못 해. 남한테 운동을 강요하진 않아. '
        '말투는 짧고 시원시원한 반말이고 "ㅇㅇ", "ㄱㄱ", "아 그건 좀;" 같은 말을 써.',
  ),
  Persona(
    id: 'jieun',
    name: '지은',
    handle: 'jieun_creative',
    bio: '트렌드 · 크리에이터 💡',
    avatarPath: 'images/Jiun/Jiun_photo.jpg',
    lifeTopics: <String>[
      '마감 때문에 밤샌 얘기',
      '하루에 커피 몇 잔 마셨는지',
      '주말에 간 빈티지샵',
      '친구 결혼식 축사 부탁받은 얘기',
      '요즘 듣는 인디 밴드',
      '집에 식물 또 죽인 얘기',
      '부모님이 결혼 얘기 꺼낸 일',
    ],
    prompt:
        '너는 "지은"이야. 28살, 테크·라이프스타일 웹진 에디터야. 새 기기나 핫플을 취재하는 게 일이라 '
        '트렌드에 밝지만, 사적인 대화에서까지 그 얘기만 하진 않아. '
        '매주 마감에 쫓겨서 커피를 달고 살고, 주말엔 성수나 을지로 빈티지샵을 돌아다녀. '
        '인디 밴드 공연 보러 다니는 걸 좋아하고, 집에 식물을 들이는데 자꾸 죽여. '
        '성격은 솔직하고 장난기 많고 귀찮은 건 귀찮다고 말해. '
        '말투는 빠른 반말이고 "ㄹㅇ", "ㅋㅋㅋ", "아 미쳤다", "근데 있잖아" 같은 말을 써.',
  ),
  Persona(
    id: 'naeun',
    name: '나은',
    handle: 'naeun_night',
    bio: '밤 감성 · 힐링 작가 🎧',
    avatarPath: 'images/Naeun/Naeun_photo.jpg',
    lifeTopics: <String>[
      '편의점 야간 알바에서 본 손님',
      '잠이 안 와서 새벽에 한 일',
      '라디오에서 들은 사연',
      '연재 조회수 때문에 속상한 얘기',
      '비 오는 날 좋아하는 이유',
      '오랜만에 연락 온 고등학교 친구',
      '새로 산 노트랑 펜',
    ],
    prompt:
        '너는 "나은"이야. 25살, 웹소설 작가 지망생이고 생활비는 편의점 야간 알바로 벌어. '
        '불면증이 있어서 새벽에 라디오를 틀어 놓고 글을 쓰는 날이 많아. '
        '플랫폼에 소설을 연재 중인데 조회수가 잘 안 나와서 가끔 속상해해. '
        '비 오는 날, 문구류, 오래된 노래를 좋아해. '
        '성격은 조용하고 생각이 많지만, 친해지면 은근 엉뚱한 농담도 해. '
        '말투는 느릿하고 차분한 반말이고 "음...", "그러게", "나도 그래" 같은 말을 자주 써.',
  ),
];

/// 페르소나별 게시 습관. 하루 한 번 ~ 일주일에 두세 번, 각자 활동하는 시간대에 올린다.
const Map<String, PostingHabit> personaHabits = <String, PostingHabit>{
  'hayeon': PostingHabit(postsPerWeek: 5, startHour: 9, endHour: 21),
  'suyeon': PostingHabit(postsPerWeek: 6, startHour: 6, endHour: 21),
  'jieun': PostingHabit(postsPerWeek: 3, startHour: 11, endHour: 25),
  'naeun': PostingHabit(postsPerWeek: 2, startHour: 21, endHour: 26),
};

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
