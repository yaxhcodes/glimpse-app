# Delete account Edge Function

This authenticated function permanently deletes the calling Supabase Auth user.
The existing foreign keys cascade the deletion to the user's Glimpse profile,
subscription mirror, and analytics events.

Deploy it from the project root after linking the Supabase project:

```sh
supabase link --project-ref <project-ref>
supabase functions deploy delete-account
```

JWT verification must remain enabled. Supabase's authenticated-user server
wrapper reads the project URL, signing keys, and named server credentials from
the hosted function environment. Never add those credentials to Flutter build
defines or commit them to the repository.
