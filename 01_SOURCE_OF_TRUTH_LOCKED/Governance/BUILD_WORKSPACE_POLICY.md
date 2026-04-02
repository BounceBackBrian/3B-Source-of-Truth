# BUILD_WORKSPACE_POLICY

## Canonical Build Rule
Each product must have one canonical build path under the canonical root.

## Required Build Metadata
For each active repo/app, record:
- package manager
- build command
- start command
- env template path
- deployment config path
- owning space

## Drift Controls
- If two buildable copies exist, designate one as canonical and immediately reclassify the other as mirror/archive.
- README files must include a "Canonical Build Path" section.
- CI/CD references must target canonical paths only.
