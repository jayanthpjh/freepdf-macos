---
name: FreePDF
description: A familiar native macOS workspace for local PDF work.
typography:
  title:
    fontFamily: "system-ui"
    fontSize: "17px"
    fontWeight: 600
  navigation:
    fontFamily: "system-ui"
    fontSize: "13px"
    fontWeight: 400
  body:
    fontFamily: "system-ui"
    fontSize: "12px"
    fontWeight: 400
  label:
    fontFamily: "system-ui"
    fontSize: "11px"
    fontWeight: 400
spacing:
  tight: "4px"
  control: "8px"
  panel: "12px"
  inset: "16px"
components:
  action-button:
    typography: "{typography.body}"
    height: "32px"
  mode-button:
    typography: "{typography.navigation}"
    height: "32px"
---

# Design System: FreePDF

## Overview

**Creative North Star: "Native Operate"**

FreePDF follows the user's Acrobat reference with a familiar professional document workspace: compact document controls, visible tool navigation, a central PDF canvas, and contextual properties. Native macOS controls supply its visual language and interaction conventions. The document is the dominant material; application chrome helps users operate on it.

The system is compact and practical. It preserves macOS menus, keyboard shortcuts, file dialogs, and window behavior. Existing-content editing, annotations, and flattened-copy operations remain distinct workflows. Capability explanations belong beside the affected controls.

**Key Characteristics:**

- Native AppKit typography and controls.
- Adaptive neutral surfaces with a restrained teal accent.
- Persistent labeled navigation and contextual inspection.
- Local document work without account prompts or cloud upsells.

## Colors

Colors use adaptive AppKit semantic roles. These are not fixed CSS colors, so frontmatter omits hex approximations that would split the native source of truth.

### Primary

- **System teal** (`NSColor.systemTeal`): selected tool navigation, content-selection outlines, and the initial annotation color. Content-selection fill uses teal at 8% opacity.

### Neutral

- **Primary label** (`NSColor.labelColor`): panel titles, ordinary descriptions, and list content.
- **Secondary label** (`NSColor.secondaryLabelColor`): supporting instructions, property captions, and status.
- **Canvas surround** (`NSColor.underPageBackgroundColor`): separates PDF pages from application chrome.
- **Editable text** (`NSColor.textColor`, `NSColor.textBackgroundColor`): native editor foreground and background.
- **Window and control surfaces**: supplied by AppKit rather than manually painted.

Pending redaction areas use `NSColor.systemRed` with an 18% fill. This denotes an operation, not a second branding accent.

**The Semantic Color Rule.** Keep adaptive native roles as the authority. Do not replace them with sampled light-mode RGB values.

## Typography

**Body and controls:** `NSFont.systemFont`, with native weight and metrics. The portable frontmatter uses `system-ui`; its pixel values represent logical Cocoa points, not physical display pixels.

### Hierarchy

- **Title:** semibold panel headings and the FreePDF sidebar name.
- **Navigation:** regular sidebar mode labels.
- **Body:** action labels, list rows, replacement text, and ordinary explanatory copy. Section headings reuse this size with semibold weight.
- **Label:** property captions, supporting explanations, and status. Small section labels may use semibold weight.

**The Document Type Rule.** Application type remains compact and native. PDF content retains the document's own typography; application fonts do not dictate exported document type.

## Layout

The workspace is a vertical sequence of document toolbar, separator, mode strip, main split view, and page/status footer. The split view places tools or thumbnails on the left, the PDF in the middle, and the contextual inspector on the right. The default window is 1280 × 820 logical points, with a 1040 × 620 minimum. The left panel is 220 points and the inspector is 258 points. Hiding the inspector recovers canvas space.

Toolbar controls use the control spacing and inset tokens; the inspector uses panel spacing and inset tokens. Tools and inspector scroll independently. Seven modes stay visible above the document: Read, Edit PDF, Annotate, Pages, Fill & Sign, Scan & OCR, and Export. All tools and page thumbnails share a two-segment sidebar switch.

**The Context Rule.** Keep document navigation stable while the inspector changes with the active workflow and selection. Long property lists scroll inside their panel.

## Elevation & Depth

Thin native split-view dividers, separators, and control bezels establish depth. The application defines no custom shadow or decorative animation system. AppKit and PDFKit retain their platform treatments.

## Shapes

Use native rounded button bezels and textured rounded segmented controls. Sidebar navigation uses borderless controls with a recessed selected treatment. Editable lists and multiline editors use native bezel borders. AppKit owns radius values; there is no custom radius scale. Selection geometry follows PDF object bounds with a two-point teal outline.

## Components

### Actions

Labeled native buttons use the recurring height and typography in frontmatter. SF Symbols may precede a label; the label remains the accessible name. Common sidebar document actions are borderless. AppKit supplies focus, hover, and pressed appearance.

### Navigation

Workflow navigation uses `NSSegmentedControl`. The sidebar repeats the workflows as labeled symbol actions, with teal tint for the current mode. The footer supplies previous/next buttons and an editable page-number field.

### Inputs

Search uses `NSSearchField`; short properties use `NSTextField`; choices use `NSPopUpButton`. Replacement text uses a plain `NSTextView` inside a scrolling bezel. Annotation color uses `NSColorWell`. Preserve native focus treatment and accessible labels.

### Context lists

An `NSTableView` lists page content, comments, or fields for the current mode. Content rows show concise labels over at most two lines, truncating longer values. Selection reveals editing controls underneath.

### Page thumbnails

Rows combine a centered PDFKit page preview and a page-number caption. Multi-selection supports page operations; local drag-and-drop supports reordering. Use actual page previews rather than decorative illustrations.

## Do's and Don'ts

### Do:

- **Do** use native semantic colors and system fonts.
- **Do** keep common workflows visible and contextual controls beside the document.
- **Do** pair symbols with clear labels and accessible names.
- **Do** explain editing, flattening, OCR, and signature limitations beside the relevant workflow.

### Don't:

- **Don't** add promotional cards, account prompts, or cloud upsells to the workspace.
- **Don't** introduce giant application typography or decorative motion.
- **Don't** make color the sole indicator of a tool or operation.
- **Don't** present signature images as certificate signatures or annotations as direct content editing.
