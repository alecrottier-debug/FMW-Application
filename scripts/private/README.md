# Local secrets — never committed

Drop your App Store Connect API key here:

    scripts/private/AuthKey_XXXXXXXXXX.p8

`.p8` files are git-ignored (see the root `.gitignore`), so this key **cannot be committed
by accident**. `../beta.sh` finds it automatically and derives the Key ID from the filename.

You set your **Issuer ID** once in `../beta.env` (copy `../beta.env.example` → `../beta.env`,
which is also git-ignored).

To get the key: App Store Connect → **Users and Access → Integrations → App Store Connect API**
→ generate a key with the **App Manager** role → download the `.p8` (one-time download).
