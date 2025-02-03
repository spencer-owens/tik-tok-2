# TikTok Clone iOS App

A modern iOS application that replicates core TikTok features, built with Swift and powered by Mux for video processing and Appwrite for backend services.

## 🚀 Tech Stack

- **Frontend**: Swift UI
- **Video Processing**: [Mux](https://mux.com)
- **Backend & Auth**: [Appwrite](https://appwrite.io)
- **Development Environment**: Xcode
- **Package Management**: Swift Package Manager

## ✨ Features

- 📱 Vertical scrolling video feed
- 🎥 Video upload and processing
- 👤 User authentication and profiles
- ❤️ Like and comment functionality
- 🔄 Follow/unfollow users
- 🎵 Background music support
- 📊 Video analytics and metrics

## 🛠 Prerequisites

- Xcode 15.0+
- iOS 16.0+
- [Mux](https://mux.com) account and API credentials
- [Appwrite](https://appwrite.io) account and project setup

## 🔧 Setup & Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/tik-tok-2.git
```

2. Open the project in Xcode:
```bash
open TikTokClone.xcodeproj
```

3. Create a `Config.xcconfig` file and add your API keys:
```
MUX_TOKEN_ID=your_mux_token_id
MUX_TOKEN_SECRET=your_mux_token_secret
APPWRITE_ENDPOINT=your_appwrite_endpoint
APPWRITE_PROJECT_ID=your_appwrite_project_id
```

4. Wait for Xcode to automatically fetch and resolve the Swift Package dependencies

## 🏗 Project Structure

```
TikTokClone/
├── App/
│   ├── TikTokCloneApp.swift
│   └── ContentView.swift
├── Features/
│   ├── Authentication/
│   ├── Feed/
│   ├── Upload/
│   └── Profile/
├── Services/
│   ├── MuxService/
│   └── AppwriteService/
└── Resources/
    └── Assets.xcassets
```

## 📱 Running the App

1. Select your target device/simulator in Xcode
2. Press ⌘R or click the "Run" button
3. The app should build and launch on your selected device

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support, email [your-email@example.com] or open an issue in the repository.

---

Made with ❤️ using Swift, Mux, and Appwrite 