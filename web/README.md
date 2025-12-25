# ENT Voice Notes - Web Application

Web client for the ENT Voice Notes medical notes management system. This application allows doctors to manage patients and create/edit medical notes manually (text only, no audio transcription).

## Prerequisites

- Node.js 18+
- npm or yarn
- Firebase project configured (same project as the mobile app)

## Setup

### 1. Install dependencies

```bash
cd web
npm install
```

### 2. Configure Firebase

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `ent-voice-notes-app`
3. Go to Project Settings > General
4. Under "Your apps", add a Web app if not already added
5. Copy the configuration values

Create a `.env.local` file in the `web` directory:

```env
NEXT_PUBLIC_FIREBASE_API_KEY=your-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=ent-voice-notes-app.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=ent-voice-notes-app
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=ent-voice-notes-app.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=526286259534
NEXT_PUBLIC_FIREBASE_APP_ID=your-web-app-id
```

### 3. Run the development server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Features

### Authentication
- Email/password login and registration
- Doctor profile auto-creation on first login
- Secure session management

### Patients (CRUD)
- Create new patients with: name, age, sex, phone
- View list of all patients
- Edit patient information
- Delete patients

### Medical Notes (CRUD - Manual Text Only)
- Create new medical notes for patients
- View all notes for a patient
- Edit existing notes
- Delete notes
- Note fields:
  - Motivo de Consulta (Chief complaint)
  - Antecedentes (Medical history)
  - Exploracion Fisica ORL (ENT physical exam)
  - Diagnostico (Diagnosis)
  - Plan de Tratamiento (Treatment plan)
  - Texto/Transcripcion (Raw text - equivalent to mobile transcription)
  - Nota Adicional (Additional notes)
  - Status (draft, in_review, signed, sent, archived)

## Architecture

The web app uses:
- **Next.js 14** with App Router
- **TypeScript** for type safety
- **Tailwind CSS** for styling
- **Firebase Auth** for authentication
- **Firestore** for database (same collections as mobile)

## Firestore Collections

The web app uses the same Firestore collections as the mobile app:

- `doctors` - Doctor profiles (document ID = auth.uid)
- `patients` - Patient records (filtered by doctor_id)
- `medical_notes` - Medical notes (filtered by doctor_id)

## Security

- All data is isolated per doctor using `doctor_id` filtering
- Firestore security rules enforce that doctors can only access their own data
- Authentication is required for all pages except login

## Important Notes

1. **No Audio/Transcription**: This web app is for manual text entry only. Audio recording and Whisper transcription are mobile-only features.

2. **Same Data Model**: The web app uses the same Firestore schema as the mobile app. Notes created on web will appear on mobile and vice versa.

3. **raw_transcript Field**: For web-created notes, the `raw_transcript` field contains the manually entered text. On mobile, this field contains the Whisper transcription.

## Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Lint code
npm run lint
```

## Deployment

The app can be deployed to any platform that supports Next.js:

- Vercel (recommended)
- Netlify
- Firebase Hosting
- Any Node.js server

Remember to set the environment variables on your deployment platform.
