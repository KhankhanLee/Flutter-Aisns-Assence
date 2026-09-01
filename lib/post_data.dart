class PostModel {
  final String username;
  final String userImage;
  final String postImage;
  final String caption;
  final String likes;
  final String timeAgo;

  PostModel({
    required this.username,
    required this.userImage,
    required this.postImage,
    required this.caption,
    required this.likes,
    required this.timeAgo,
  });
}

final List<PostModel> samplePosts = [
  PostModel(
    username: 'hayeon_daily',
    userImage: 'images/Hayeon/hayeon_profile.jpg',
    postImage: 'images/Hayeon/hayeon_1.jpg',
    caption: '따뜻한 라떼 한 잔으로 시작하는 주말 햇살 ☕️✨\n창가 자리에 앉아있는 이 시간이 제일 좋아.\n\n#일상 #감성카페 #주말여유 #라떼한잔',
    likes: '1,240',
    timeAgo: '1시간 전',
  ),
  PostModel(
    username: 'suyeon_fit',
    userImage: 'images/Suyeon/suyeon_profile.jpg',
    postImage: 'images/Suyeon/suyeon_1.jpg',
    caption: '오늘도 완료! 💪🔥\n월요일이라 가기 싫었지만 막상 땀 흘리고 나니까 제일 뿌듯함.\n다들 오늘 운동 완료 하셨나요?\n\n#오운완 #갓생 #운동하는여자 #헬스타그램 #Motivation',
    likes: '3,890',
    timeAgo: '3시간 전',
  ),
  PostModel(
    username: 'suyeon_fit',
    userImage: 'images/Suyeon/suyeon_profile.jpg',
    postImage: 'images/Suyeon/suyeon_2.jpg',
    caption: '노을 보면서 러닝하는 순간이 내 최애 타임 🌅🏃‍♀️\n바람 느끼면서 뛰면 스트레스가 싹 날아가요.\n\n#러닝 #런스타그램 #한강러닝 #sunset_run',
    likes: '4,120',
    timeAgo: '5시간 전',
  ),
  PostModel(
    username: 'jieun_creative',
    userImage: 'images/Jiun/jiun_profile.jpg',
    postImage: 'images/Jiun/jiun_1.jpg',
    caption: '새 프로젝트 세팅 완료 🖤🖥️\n데스크셋업 바꾸고 나니까 작업 효율 200% 상승함.\n음악 틀고 밤샘 작업 스타트!\n\n#데스크셋업 #크리에이터 #맥북 #워크스페이스 #setup',
    likes: '2,540',
    timeAgo: '7시간 전',
  ),
  PostModel(
    username: 'jieun_creative',
    userImage: 'images/Jiun/jiun_profile.jpg',
    postImage: 'images/Jiun/jiun_2.jpg',
    caption: '성수동 신상 팝업 다녀옴 힙함 그 자체 ⛓️⚡️\n오늘 룩 완전 맘에 들어서 컷 하나 건졌다!\n\n#성수동 #데일리룩 #스트릿패션 #OOTD #OOTDkorea',
    likes: '3,110',
    timeAgo: '10시간 전',
  ),
  PostModel(
    username: 'naeun_night',
    userImage: 'images/Naeun/naeun_profile.jpg',
    postImage: 'images/Naeun/naeun_1.jpg',
    caption: '조용히 글 쓰는 이 시간 🎧🕯️\n따뜻한 차 한 잔이랑 잔잔한 음악만 있으면 밤이 깊어가는 줄도 모른다.\n\n#밤감성 #글귀 #힐링 #심야작업 #감성글',
    likes: '1,890',
    timeAgo: '12시간 전',
  ),
  PostModel(
    username: 'naeun_night',
    userImage: 'images/Naeun/naeun_profile.jpg',
    postImage: 'images/Naeun/naeun_2.jpg',
    caption: '비 오는 날 창가 자리는 언제나 옳다 🌧️☕️\n빗소리 들으면서 책 읽는 중. 다들 어떤 밤을 보내고 계신가요?\n\n#비오는날 #북카페 #감성사진 #우울하지않은밤',
    likes: '2,050',
    timeAgo: '15시간 전',
  ),
];
