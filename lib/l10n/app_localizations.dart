// lib/l10n/app_localizations.dart
//
// Minimal localization stub for the admin app.
// Returns English strings derived from the original kleenops localizations.
// This avoids depending on the full l10n system for migrated screens.

import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations._();

  static const AppLocalizations _instance = AppLocalizations._();

  static AppLocalizations? of(BuildContext context) => _instance;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
  ];

  // ── Common ──
  String get commonAdd => 'Add';
  String get commonCancel => 'Cancel';
  String get commonDelete => 'Delete';
  String get commonDescription => 'Description';
  String get commonDetails => 'Details';
  String get commonDocumentNotFound => 'Document not found';
  String get commonEdit => 'Edit';
  String get commonName => 'Name';
  String get commonNotAvailable => 'N/A';
  String get commonSave => 'Save';
  String get commonSearch => 'Search';
  String get commonUnknown => 'Unknown';
  String get commonUnnamed => 'Unnamed';
  String commonErrorWithDetails(String details) => 'Error: $details';

  // ── Catalog / Objects ──
  String get catalogDetailsTitle => 'Product Details';
  String get catalogFormEditProductTitle => 'Edit Product';
  String get catalogFormScalarLabel => 'Quantity';
  String get catalogFormScalarUnitLabel => 'Unit';
  String get catalogIdentifiersTitle => 'Identifiers';
  String get catalogProductCodeLabel => 'Product Code';
  String get objectsFormBarcodeLabel => 'Barcode';
  String get objectsInventoryRequiredField => 'Required';
  String get objectsNoObjectsFound => 'No objects found';
  String get objectsPerCase => 'per case';
  String get objectsSearchProducts => 'Search products';
  String get facilitiesInventoryQuantityLabel => 'Quantity';

  // ── Marketplace / Scraping ──
  String get marketplaceTitle => 'Catalog';
  String get marketplaceWebScrapingTitle => 'Web Scraping';
  String get marketplaceSitesTab => 'Vendor Sites';
  String get marketplaceSiteJobsTab => 'Scrape Jobs';
  String get marketplaceDetailJobsTab => 'Detail Jobs';
  String get marketplaceNeedsReviewTab => 'Needs Review';
  String get marketplaceAutoApprovedTab => 'Auto-Approved';
  String get marketplaceProcessedTab => 'New Items';
  String get marketplaceStagingReviewTitle => 'Staging Review';
  String get marketplaceStagedProductDetailsTitle => 'Staged Product';
  String get marketplaceImportCatalogPdfTitle => 'Import Catalog PDF';

  // Vendor config
  String get marketplaceAddVendor => 'Add Vendor';
  String get marketplaceEditVendor => 'Edit Vendor';
  String get marketplaceAddVendorToStart => 'Add a vendor to get started';
  String get marketplaceVendorNameRequired => 'Vendor name is required';
  String get marketplaceVendorNameOptional => 'Vendor Name';
  String get marketplaceVendorNameOptionalHint => 'Enter vendor name';
  String get marketplaceVendor => 'Vendor';
  String get marketplaceNoVendorConfigurations => 'No vendor configurations';
  String get marketplaceNoVendorConfigurationsFoundAddVendor =>
      'No vendor configurations found. Add a vendor to start.';
  String get marketplaceDeleteVendorConfigTitle => 'Delete Vendor Config';
  String marketplaceDeleteVendorConfigConfirm([dynamic name]) =>
      name != null ? 'Delete "$name"? This cannot be undone.' : 'Are you sure? This cannot be undone.';
  String get marketplaceVendorConfigDeleted => 'Vendor config deleted';
  String get marketplaceVendorConfigurationSaved => 'Vendor config saved';
  String get marketplaceSaveConfiguration => 'Save Configuration';
  String marketplaceSaveFailed([dynamic details]) =>
      details != null ? 'Save failed: $details' : 'Save failed';

  // Scrape jobs
  String get marketplaceCreateScrapeJobTitle => 'Create Scrape Job';
  String get marketplaceCreateDetailExtractionJobTitle =>
      'Create Detail Job';
  String get marketplaceCreateJob => 'Create Job';
  String get marketplaceCreateNew => 'Create New';
  String get marketplaceStartScrape => 'Start Scrape';
  String get marketplaceNoScrapeJobsYet => 'No scrape jobs yet';
  String get marketplaceCreateVendorConfigFirst =>
      'Create a vendor config first';
  String get marketplaceJobCancelled => 'Job cancelled';
  String get marketplaceJobRequeued => 'Job requeued';
  String get marketplaceScrapeJobCreated => 'Scrape job created';
  String get marketplaceRetry => 'Retry';
  String get marketplaceRerun => 'Rerun';
  String get marketplaceFullCatalog => 'Full Catalog';
  String get marketplaceJobTypeLabel => 'Job Type';
  String get marketplaceStartPageLabel => 'Start Page';
  String get marketplaceEndPageLabel => 'End Page';
  String get marketplaceFirstPageToScrape => 'First page to scrape';
  String get marketplaceLastPageToScrape => 'Last page to scrape';
  String get marketplaceWorking => 'Working...';
  String get marketplaceCreating => 'Creating...';
  String get marketplaceSaving => 'Saving...';
  String get marketplacePagesLabel => 'Pages';
  String get marketplaceFoundLabel => 'Found';
  String get marketplaceStagedLabel => 'Staged';
  String get marketplaceFailedLabel => 'Failed';
  String get marketplaceTotalLabel => 'Total';
  String marketplaceItemsTotal([dynamic count]) =>
      count != null ? '$count total' : 'Items Total';
  String marketplaceItemsFound([dynamic count]) =>
      count != null ? '$count found' : 'Items Found';
  String marketplaceActionFailed(String e) => 'Action failed: $e';
  String marketplaceItemsProcessedProgress(dynamic done, dynamic total) =>
      '$done / $total processed';

  // Auto-detect / analysis
  String get marketplaceAnalyzing => 'Analyzing...';
  String get marketplaceAutoDetect => 'Auto-Detect';
  String get marketplaceAutoDetectCatalogSettings =>
      'Auto-detect catalog settings';
  String get marketplaceAnalyzingCatalogPage => 'Analyzing catalog page...';
  String get marketplaceAnalyzingDetailPage => 'Analyzing detail page...';
  String get marketplaceDetectingDescriptionSpecsUpc =>
      'Detecting description, specs, UPC...';
  String get marketplaceDetectingLayoutSelectorsPagination =>
      'Detecting layout, selectors, pagination...';
  String get marketplaceDetectionSuccessful => 'Detection successful';
  String get marketplaceDetectionNeedsReview => 'Detection needs review';
  String get marketplaceReanalyze => 'Re-analyze';
  String get marketplaceReanalyzeSelectors => 'Re-analyze selectors';
  String marketplaceReanalysisComplete([dynamic count, dynamic confidence]) =>
      count != null ? 'Re-analysis complete: $count products, $confidence% confidence' : 'Re-analysis complete';
  String marketplaceReanalysisFailed([dynamic details]) =>
      details != null ? 'Re-analysis failed: $details' : 'Re-analysis failed';
  String get marketplaceCatalogPageUrlHint => 'https://...';
  String get marketplaceCatalogPageUrlRequired => 'Catalog URL is required';
  String get marketplaceEnterCatalogUrlFirst => 'Enter a catalog URL first';
  String get marketplacePasteCatalogUrlHelp =>
      'Paste the vendor catalog URL';
  String get marketplaceJavascriptDetectedForSite =>
      'JavaScript rendering detected';
  String get marketplaceRequiresJavascript => 'Requires JavaScript';
  String get marketplaceUsesCheerio => 'Static HTML (Cheerio)';
  String get marketplaceUsesPuppeteer => 'JavaScript (Playwright)';
  String marketplacePageWithUrl(String url) => 'Page: $url';
  String marketplaceSampleProductsFound(int count) =>
      '$count sample products found';
  String marketplaceFoundWithSelector(String sel) => 'Found with: $sel';
  String get marketplaceNoSampleValueDetected => 'No sample value detected';

  // CSS selectors
  String get marketplaceCssSelectorsTitle => 'CSS Selectors';
  String get marketplaceDescriptionSelector => 'Description Selector';
  String get marketplaceSpecsTableSelector => 'Specs Table Selector';
  String get marketplaceSpecsSelectorHelp => 'CSS selector for specs table';
  String get marketplaceDownloadLinksTitle => 'Download Links';
  String get marketplaceDownloadLinksHelp => 'Selectors for download links';
  String get marketplaceSdsLinks => 'SDS Links';
  String get marketplaceProductSheetLinks => 'Product Sheet Links';
  String get marketplaceImageLinks => 'Image Links';

  // Detail templates
  String get marketplaceDetailExtraction => 'Detail Extraction';
  String get marketplaceDetailExtractionJobHelp =>
      'Creates jobs to extract detail data from product pages';
  String get marketplaceNewDetailTemplate => 'New Detail Template';
  String get marketplaceEditDetailTemplate => 'Edit Detail Template';
  String get marketplaceNoDetailTemplatesYet => 'No detail templates yet';
  String get marketplaceNoDetailTemplatesFoundCreateInDetails =>
      'No templates found. Create one in the Details tab.';
  String get marketplacePressPlusCreateDetailTemplate =>
      'Press + to create a detail template';
  String get marketplaceDetailTemplateSaved => 'Detail template saved';
  String get marketplaceDetailTemplateLabel => 'Detail Template';
  String get marketplaceDeleteTemplateTitle => 'Delete Template';
  String marketplaceDeleteTemplateConfirm([dynamic name]) =>
      name != null ? 'Delete "$name"? This cannot be undone.' : 'Are you sure? This cannot be undone.';
  String get marketplaceTemplateNameHint => 'Template name';
  String get marketplaceTemplateNameRequired => 'Template name is required';
  String get marketplaceSaveTemplate => 'Save Template';
  String get marketplaceNoDetailExtractionJobsYet => 'No detail jobs yet';
  String get marketplaceConfigureDetailSelectorsFirst =>
      'Configure detail selectors first';
  String marketplaceDetailJobCreatedForItems(int count) =>
      'Detail job created for $count items';

  // Staging review
  String get marketplaceSearchStagedItems => 'Search staged items';
  String get marketplaceSearchStagedProducts => 'Search staged products';
  String get marketplaceSearchProducts => 'Search products';
  String get marketplaceNoStagedProductsFound => 'No staged products found';
  String get marketplaceNoStagedProductsMatchSearch =>
      'No staged products match search';
  String get marketplaceNoItemsNeedReview => 'No items need review';
  String marketplaceNoItemsMatch([dynamic query]) =>
      query != null ? 'No items match "$query"' : 'No items match';
  String get marketplaceNoItemsInCategory => 'No items in this category';
  String get marketplaceNoProductsFound => 'No products found';
  String get marketplaceApprove => 'Approve';
  String get marketplaceApproved => 'Approved';
  String get marketplaceReject => 'Reject';
  String get marketplaceRejected => 'Rejected';
  String get marketplaceRejectProductTitle => 'Reject Product';
  String get marketplaceRejectItemTitle => 'Reject Item';
  String get marketplaceReasonOptional => 'Reason (optional)';
  String get marketplaceEnterReasonOptional => 'Enter reason (optional)';
  String get marketplaceProductApprovedSuccessfully => 'Product approved';
  String get marketplaceProductRejected => 'Product rejected';
  String marketplaceApprovalFailed([dynamic details]) =>
      details != null ? 'Approval failed: $details' : 'Approval failed';
  String marketplaceRejectFailed([dynamic details]) =>
      details != null ? 'Reject failed: $details' : 'Reject failed';
  String get marketplaceRejectedByReviewer => 'Rejected by reviewer';
  String marketplaceApproveAllItems([dynamic count]) =>
      count != null ? 'Approve All ($count)' : 'Approve All';
  String marketplaceApproveItemCount(int count) => 'Approve $count items';
  String marketplaceApprovedItems([dynamic count]) =>
      count != null ? '$count items approved' : 'Approved Items';
  String marketplaceBulkApproveFailed([dynamic details]) =>
      details != null ? 'Bulk approve failed: $details' : 'Bulk approve failed';
  String get marketplaceSaveChangesTitle => 'Save Changes';
  String get marketplaceNoItemsToSave => 'No items to save';
  String get marketplaceDeleteCannotUndo =>
      'Are you sure? This cannot be undone.';

  // Product details in staging
  String get marketplaceSkuProductNumber => 'SKU / Product Number';
  String get marketplaceProductNumber => 'Product Number';
  String get marketplaceUpc => 'UPC';
  String get marketplaceUpcBarcode => 'UPC / Barcode';
  String get marketplaceUnitSize => 'Unit Size';
  String get marketplaceUnitOfMeasure => 'Unit of Measure';
  String get marketplaceBrand => 'Brand';
  String get marketplaceUnknownBrand => 'Unknown Brand';
  String get marketplaceUnnamedBrand => 'Unnamed Brand';
  String get marketplaceUnknownVendor => 'Unknown Vendor';
  String get marketplaceUnnamedVendor => 'Unnamed Vendor';
  String get marketplaceUnnamedProduct => 'Unnamed Product';
  String get marketplaceDefaultProductName => 'Product';
  String get marketplaceUntitled => 'Untitled';
  String get marketplaceLink => 'Link';
  String get marketplaceLinkExisting => 'Link Existing';
  String get marketplaceNewProduct => 'New Product';
  String get marketplaceProductUpdate => 'Product Update';
  String get marketplacePriceUpdate => 'Price Update';
  String get marketplaceNoMatchFound => 'No match found';
  String marketplaceMatchWithScore(dynamic strategy, [dynamic score]) =>
      score != null ? 'Match: $strategy ($score%)' : 'Match ($strategy%)';
  String marketplaceConfidencePercent(dynamic score) =>
      score is double ? '${(score * 100).toStringAsFixed(0)}%' : '$score%';
  String marketplaceConfidenceTooltip([dynamic score]) =>
      score != null ? 'Confidence: $score' : 'Match confidence';
  String marketplaceSkuWithValue(String sku) => 'SKU: $sku';
  String marketplaceUpcWithValue(String upc) => 'UPC: $upc';
  String marketplaceQuantityWithValue(dynamic qty) => 'Qty: $qty';
  String get marketplaceOptional => '(optional)';
  String get marketplaceRequired => 'Required';
  String get marketplaceNotesLabel => 'Notes';
  String get marketplaceOkLabel => 'OK';
  String get marketplaceNotDetected => 'Not detected';
  String get marketplaceLeaveBlankAutoGenerate => 'Leave blank to auto-generate';
  String marketplaceSelectedVendorAndUrl([dynamic vendor, dynamic url]) =>
      vendor != null ? '$vendor — $url' : 'Selected vendor and URL';
  String get marketplaceRemove => 'Remove';

  // PDF import
  String get marketplaceCatalogNameLabel => 'Catalog Name';
  String get marketplaceCatalogNameRequired => 'Catalog name is required';
  String get marketplaceDescriptionOptional => 'Description (optional)';
  String get marketplaceFormBrandLabel => 'Brand';
  String get marketplaceFormValidationSelectBrand => 'Select a brand';
  String get marketplaceNoBrandsYet => 'No brands yet';
  String get marketplaceNoVendorsYet => 'No vendors yet';
  String get marketplaceSelectPdf => 'Select PDF';
  String get marketplaceSelectPdfToUpload => 'Select a PDF to upload';
  String get marketplaceUploadAndProcess => 'Upload & Process';
  String get marketplaceUploadFailed => 'Upload failed';
  String get marketplaceCatalogUploadedProcessingStarted =>
      'Catalog uploaded, processing started';

  // ── Common (extended) ──
  String get commonCharts => 'Charts';
  String get commonRecords => 'Records';
  String get commonSelect => 'Select';
  String get commonOk => 'OK';
  String commonPlaceholder(String label) => 'Enter $label';

  // ── Navigation ──
  String get nav_processes => 'Processes';

  // ── Search ──
  String get searchFieldActionTapToChoose => 'Tap to choose';

  // ── Object Element Details ──
  String get objectElementDetailsTitle => 'Element Details';
  String get objectElementDetailsElementLabel => 'Element';
  String get objectElementDetailsUnnamedElement => 'Unnamed Element';
  String get objectElementDetailsUnknownMaterial => 'Unknown Material';
  String get objectElementDetailsUnnamedMaterial => 'Unnamed Material';
  String get objectElementDetailsPercentOfObject => '% of Object';
  String get objectElementDetailsDefaultStandardUnit => 'unit';
  String objectElementDetailsMeasurementWithUnit(String unit) =>
      'Measurement ($unit)';
  String get objectElementDetailsMaterialHeader => 'Material';
  String get objectElementDetailsDimensionsHeader => 'Dimensions';
  String get objectElementDetailsNameHeader => 'Name';

  // ── Object Element Form ──
  String get objectElementFormTitleEdit => 'Edit Element';
  String get objectElementFormTitleNew => 'New Element';
  String get objectElementFormImagesTitle => 'Images';
  String get objectElementFormElementHeader => 'Element';
  String get objectElementFormElementNameLabel => 'Element Name';
  String get objectElementFormRequired => 'Required';
  String get objectElementFormElementPercentageHeader => 'Percentage';
  String get objectElementFormPercentRange => '0-100';
  String get objectElementFormMeasuredByLabel => 'Measured By';
  String objectElementFormMeasurementLabel(String unit) => 'Measurement ($unit)';
  String get objectElementFormInvalid => 'Invalid';
  String get objectElementFormDimensionsTitle => 'Dimensions';
  String get objectElementFormLengthMetricLabel => 'Length (m)';
  String get objectElementFormLengthLabel => 'Length (ft)';
  String get objectElementFormWidthMetricLabel => 'Width (m)';
  String get objectElementFormWidthLabel => 'Width (ft)';
  String get objectElementFormHeightMetricLabel => 'Height (m)';
  String get objectElementFormHeightLabel => 'Height (ft)';
  String get objectElementFormElementMaterialLabel => 'Material';
  String get objectElementFormNoImageToMarkup => 'No image to mark up';

  // ── Object Process Details ──
  String get objectProcessDetailsTitle => 'Process Details';
  String get objectProcessDetailsNoDetailsAvailable => 'No details available';
  String get objectProcessDetailsNoMaterialsFound => 'No materials found';
  String get objectProcessDetailsNoToolsFound => 'No tools found';
  String get objectProcessDetailsStatementHeader => 'Statement';
  String get objectProcessDetailsInstructionsHeader => 'Instructions';
  String get objectsDetailsSectionElements => 'Elements';
  String get processesDetailsHeaderMaterials => 'Materials';
  String get processesDetailsHeaderTools => 'Tools';
  String get objectProcessDetailsNoMaterialsFoundLabel =>
      'No materials found';
  String get objectProcessDetailsNoToolsFoundLabel => 'No tools found';

  // ── Object Process Form ──
  String objectsProcessFailedToSave(String e) => 'Failed to save: $e';
  String get objectsProcessSelectProcessTitle => 'Select Process';
  String get objectsProcessNoProcessesFound => 'No processes found';
  String get objectsProcessLabel => 'Process';
  String get objectsProcessNoMatchingResources => 'No matching resources';
  String get objectsProcessNoMatchingElements => 'No matching elements';
  String get objectsProcessStatementLabel => 'Statement';
  String get objectsProcessEnterStatement => 'Enter statement';
  String get objectsProcessInstructionsLabel => 'Instructions';
  String get objectsProcessEnterInstructions => 'Enter instructions';
  String get objectsProcessAddFileTitle => 'Files';
  String get objectsProcessSelectObjectElementsTitle => 'Select Elements';

  // ── Objects Inventory Form ──
  String get objectsInventoryFillAllRequiredFields =>
      'Please fill all required fields';
  String get objectsInventoryAdded => 'Inventory added';
  String objectsInventoryFailedToSave(String e) => 'Failed to save: $e';
  String get objectsInventoryAddTitle => 'Add Inventory';
  String get objectsFormSerialNumberLabel => 'Serial Number';
  String get objectsFormAssetTagLabel => 'Asset Tag';
  String get objectsInventoryPercentCoverageLabel => 'Coverage (%)';
  String get objectsInventoryEnterNumber => 'Enter number';
  String get objectsInventoryRangeZeroToHundred => '0-100';
  String get objectsInventoryQuantityPerLocationLabel => 'Qty per Location';
  String get objectsInventoryWholeNumber => 'Whole number';
  String get objectsInventoryRealtimeTrackingLabel => 'Realtime Tracking';
  String get objectsInventoryRealtimeTrackingDescription =>
      'Enable sensor-based equipment monitoring';

  // Product variants
  String marketplaceVariantsTitle([dynamic name]) =>
      name != null ? '$name — Variants' : 'Variants';
  String get marketplacePackagingTab => 'Packaging';
  String get marketplacePartsTab => 'Parts';
  String get marketplaceNoPackagingVariants => 'No packaging variants';
  String get marketplaceNoComponentParts => 'No component parts';
  String get marketplaceAddPackagingVariant => 'Add Packaging Variant';
  String get marketplaceEditPackagingVariant => 'Edit Packaging Variant';
  String get marketplaceDeletePackagingVariantTitle => 'Delete Variant';
  String get marketplaceAddPackagingOptionsHint => 'e.g. Case, Box, Pallet';
  String get marketplaceAddReplacementPartsHint => 'e.g. Filter, Brush, Pad';
  String get marketplaceAddComponentPart => 'Add Component Part';
  String get marketplaceRemoveFromProduct => 'Remove from Product';
  String get marketplaceRemovePartTitle => 'Remove Part';
  String get marketplaceRemovePartBody =>
      'Remove this part from the product?';
  String get marketplaceSelectPartToLink => 'Select part to link';
  String get marketplacePackagingType => 'Packaging Type';
  String get marketplacePackagingTypeCase => 'Case';
  String get marketplacePackagingTypeBox => 'Box';
  String get marketplacePackagingTypePack => 'Pack';
  String get marketplacePackagingTypeBundle => 'Bundle';
  String get marketplacePackagingTypePallet => 'Pallet';
  String get marketplacePackagingTypeEach => 'Each';
  String get marketplacePackagingTypeBag => 'Bag';
  String get marketplaceQuantityPerPackageHint => 'Quantity per package';
  String get marketplaceQuantityPerPackageRequired => 'Quantity is required';
  String get marketplaceEnterValidQuantity => 'Enter a valid quantity';
  String get marketplaceVariantNameOptional => 'Variant name (optional)';
  String get marketplaceVariantNameRequired => 'Variant name is required';
  String get marketplacePackagingVariantCreated => 'Packaging variant created';
  String get marketplaceVariantUpdated => 'Variant updated';
  String get marketplaceVariantDeleted => 'Variant deleted';
  String get marketplacePartNameRequired => 'Part name is required';
  String get marketplacePartAdded => 'Part added';
  String get marketplacePartRemoved => 'Part removed';
  String get marketplaceRequiredPart => 'Required Part';
  String get marketplaceRequiredPartHelp => 'Part is required for product';
  String get marketplaceErrorLoadingVariants => 'Error loading variants';
  String get marketplaceRefreshDebug => 'Refresh';
  String get marketplaceUnnamedPart => 'Unnamed Part';
}
