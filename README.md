# SnapLingo

SnapLingo is an iOS vocabulary learning app for turning real-world English text into reviewable flashcards.

The app uses photo capture and OCR to extract words from everyday materials, lets learners choose the words they want to keep, and schedules reviews with a spaced repetition workflow.

## Current Features

- Photo-based text capture with Apple's Vision OCR.
- Word selection from recognized text blocks.
- Vocabulary details and review history stored with SwiftData.
- SM-2 style spaced repetition scheduling.
- Review dashboard with due words, mastered words, streaks, and recent scan sessions.

## Why This Exists

Many language-learning apps start from preset word lists. SnapLingo focuses on the words a learner actually meets in daily life, preserving the original capture context and turning it into a repeatable study loop.

## Tech Stack

- SwiftUI
- SwiftData
- Vision OCR
- Keychain-backed API key storage

## Status

This is an active portfolio project. The next useful improvements are clearer onboarding, better scan-session notes, and a small demo walkthrough for reviewers.
