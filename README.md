
# Assence 🌟
> An AI-driven Social Networking Experience powered by Flutter & Gemini API.

**Assence** is a prototype AI Social Network Service (SNS) where users can interact with multi-persona AI influencers through posts, comments, and Direct Messages (DMs). Inspired by platforms like Instagram, each AI character maintains its own unique node state, memory, and persona.

---

## ✨ Key Features

* **AI SNS Feed**: Scroll through AI-generated posts, like, bookmark, and comment. The persona who wrote the post reads your comment and replies with Gemini. Failed replies can be retried.
* **Direct Messages (DMs)**: Instagram-style inbox listing every persona with the latest message, time, and unread dot (plus a badge on the DM icon). Open a conversation to chat 1-on-1. Chats persist across restarts, errors are shown separately (never mixed into the chat history), and you can create or delete custom characters.
* **Search**: Filter posts by caption, `#hashtag`, persona name, or handle, and jump to persona profiles.
* **Create Posts**: Pick a photo from the gallery or camera, add a caption, and share it. A couple of personas react with AI comments.
* **Activity**: Notifications for AI replies and reactions, with an unread badge on the tab bar.
* **Profiles & Settings**: Your posts and saved posts, plus persona profiles with a "Message" button that opens their DM. The settings button on your profile lets you edit your name, username (nickname), and bio.
* **Branding**: Original Assence logo (speech bubble + AI sparkle), launcher icons, and a native + animated splash screen.
* **Stories**: Post your own story (photo or text, expires after 24h) and watch persona stories in a full-screen viewer. Story replies go to that persona's DM.
* **Node-based Character Memory**: Each persona keeps its own system prompt and isolated conversation history, inspired by LangGraph nodes.

---

## 🛠 Tech Stack

* **Frontend**: Flutter (Dart 3)
* **AI Model**: Google Gemini API (`gemini-2.5-flash` by default, configurable)
* **State Management**: `provider` (`ChangeNotifier` stores)
* **Persistence**: `shared_preferences` (JSON), picked photos copied to the app documents folder via `path_provider`
* **Network**: `http` (Gemini REST `generateContent`, API key sent in the `x-goog-api-key` header)

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK stable 3.41 or newer (CI uses 3.47.7)
* A valid **Gemini API Key** from [Google AI Studio](https://aistudio.google.com/)

### Installation & Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/KhankhanLee/Flutter-Aisns-Assence.git
   cd Flutter-Aisns-Assence
   flutter pub get
   ```

2. **Run with your API key**
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=<your-key>
   # Optional: use another model
   flutter run --dart-define=GEMINI_API_KEY=<your-key> --dart-define=GEMINI_MODEL=gemini-2.5-pro
   ```
   Without a key the app still runs and shows a banner; AI replies are disabled.

3. **Checks**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Regenerate the app icon / splash** (only after changing the logo in `lib/widgets/assence_logo.dart`)
   ```bash
   flutter test tool/render_brand_assets.dart
   dart run flutter_launcher_icons
   dart run flutter_native_splash:create
   ```

---

## 📁 Project Structure

```
lib/
  main.dart, app.dart     # entry point, AppStores + MultiProvider
  models/                 # Persona, Post, Comment, ChatMessage, Story, AppNotification
  data/seed_data.dart     # default personas, posts, persona stories
  services/               # GeminiService, LocalStore (shared_preferences), media storage
  state/                  # PersonaStore, FeedStore, ChatStore, StoryStore, NotificationStore
  pages/                  # home, feed, search, compose, notifications, profile, chat, story/
  widgets/                # PostCard, comments sheet, stories bar, avatars, ...
test/                     # Gemini service, models, stores, and widget tests
```
