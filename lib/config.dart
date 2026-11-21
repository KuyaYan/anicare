// ============================================================================
//  SUPABASE SETTINGS  –  the ONLY place you need to edit to switch on syncing.
//
//  * Leave both values empty ('')  -> the app works offline on this phone only
//                                     (local SQLite, like version 5.0.0).
//  * Fill both values              -> the app signs in and syncs through Supabase,
//                                     so several phones share the same data.
//
//  Where to find them: Supabase dashboard -> Project Settings -> API
//     kSupabaseUrl     = "Project URL"        (https://xxxx.supabase.co)
//     kSupabaseAnonKey = "anon / public key"  (the long eyJ... text)
//  Full steps: see supabase-and-maya-guide.md
// ============================================================================
const String kSupabaseUrl = 'https://trqioxrzirftyldwpsso.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_PGFKTuh2ZFI5E3Z4jFW7vQ_8FlbXtJO';
// Supabase Storage bucket for animal / vet / shop / product photos (created in the Supabase steps)
const String kPhotoBucket = 'photos';
