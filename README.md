# Spicyreel frontend (Step 1: Login + Profile setup) - v5, asli Google/Facebook login

## Kaise chalayein
Google/Facebook login double-click se nahi chalta. VS Code mein:
1. Extension "Live Server" install karein.
2. index.html par right-click -> Open with Live Server. (Address aisa hoga: http://127.0.0.1:5500)

## Google login chalu karna (free)
1. https://console.cloud.google.com par jayein, naya project banayein.
2. "APIs & Services" -> "OAuth consent screen" (ya Google Auth Platform): app ka naam Spicyreel, apni email, User type: External.
   Jab tak app "Testing" mein hai, sirf "Test users" mein likhi emails login kar sakti hain. Sab ke liye kholne ke liye "Publish app" karein.
3. "Credentials" -> Create Credentials -> OAuth client ID -> Application type: Web application.
4. "Authorized JavaScript origins" mein ye dono daalein:
   http://127.0.0.1:5500
   http://localhost:5500
5. Jo Client ID mile, usay js/config.js mein GOOGLE_CLIENT_ID mein paste karein. Page refresh karein.

## Facebook login chalu karna (free)
1. https://developers.facebook.com -> Create App -> "Facebook Login" product jodein.
2. App ID ko js/config.js mein FACEBOOK_APP_ID mein paste karein.
3. Jab tak app "Development" mode mein hai, sirf aap (admin) ya aap ke jode hue testers login kar sakte hain.
   Sab ke liye kholne ke liye Privacy Policy URL dena hota hai aur app ko Live karna hota hai.
4. Facebook ko asli server par HTTPS chahiye. Apne computer par localhost par test ho jata hai.

## Folder ka naqsha
index.html                     -> dhancha + sab files ki tarteeb
css/base.css, css/onboarding.css -> styling
js/config.js                   -> Google/Facebook IDs yahan likhein
js/utils.js, js/state.js       -> helpers aur data save/load
js/services/auth.js            -> username ke qaide
js/services/social-login.js    -> asli Google aur Facebook login
js/components/info-sheet.js    -> chhoti maloomati sheet
js/screens/welcome.js          -> Screen 1: login
js/screens/profile-setup.js    -> Screen 2: naam, username, bio, photo
js/screens/home.js             -> Screen 3: abhi placeholder (agla step: reel feed)
js/main.js                     -> screens ke beech jaana
