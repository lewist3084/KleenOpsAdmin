/* ────────────────────────────────────────────────────────────
   lib/features/onboarding/guides/setup_guide_data.dart
   – Data model and definitions for contextual setup guides.
   – Each guide has a unique key, a set of slides, and belongs
     to a section of the app.
   ──────────────────────────────────────────────────────────── */
import 'package:flutter/material.dart';

/* ─── Slide model ─────────────────────────────────────────── */

class GuideSlide {
  const GuideSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color color;
}

/* ─── Guide model ─────────────────────────────────────────── */

class SetupGuide {
  const SetupGuide({
    required this.key,
    required this.title,
    required this.slides,
  });

  /// Unique key stored in Firestore for permanent dismissal.
  final String key;

  /// Display title (shown in menu drawer).
  final String title;

  /// Ordered slides for the carousel.
  final List<GuideSlide> slides;
}

/* ═══════════════════════════════════════════════════════════
   Guide definitions — KleenOps Admin (platform operator)
   ═══════════════════════════════════════════════════════════ */

const mainGuide = SetupGuide(
  key: 'main',
  title: 'Getting Started',
  slides: [
    GuideSlide(
      icon: Icons.admin_panel_settings,
      title: 'Welcome to KleenOps Admin',
      body: 'Your command center for managing the KleenOps platform. '
          'Set up your business operations, oversee client companies, '
          'and keep everything running smoothly.',
      color: Color(0xFF002E5D),
    ),
    GuideSlide(
      icon: Icons.business,
      title: 'Set Up Your Business',
      body: 'Configure your platform company identity, register your '
          'domain, and complete your business formation — all from '
          'the Admin section.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.account_balance,
      title: 'Connect Your Finances',
      body: 'Link your bank accounts with Plaid, set up payment '
          'processing with Stripe, and manage invoicing and payroll.',
      color: Color(0xFF6A1B9A),
    ),
    GuideSlide(
      icon: Icons.people,
      title: 'Build Your Team',
      body: 'Add employees, assign roles, set up benefits, and '
          'manage onboarding workflows for your platform team.',
      color: Color(0xFFC62828),
    ),
    GuideSlide(
      icon: Icons.gavel,
      title: 'Stay Compliant',
      body: 'Upload legal documents, track insurance expirations, '
          'and manage contracts — the Legal section keeps you covered.',
      color: Color(0xFF2E7D32),
    ),
  ],
);

const financeGuide = SetupGuide(
  key: 'finance',
  title: 'Finance Setup',
  slides: [
    GuideSlide(
      icon: Icons.account_balance,
      title: 'Connect Your Bank',
      body: 'Link your platform business bank account securely '
          'with Plaid for automated reconciliation and reporting.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.credit_card,
      title: 'Payment Processing',
      body: 'Stripe is pre-configured for your platform. Accept '
          'payments from client companies and manage billing '
          'with no additional setup fees.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.receipt_long,
      title: 'Invoicing & Bills',
      body: 'Create invoices for client companies, track bills '
          'from vendors, and manage all payment flows from one place.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.account_balance_wallet,
      title: 'Payroll & Reporting',
      body: 'Run payroll for your platform team, generate W-2s, '
          'and track revenue, expenses, and profitability.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const hrGuide = SetupGuide(
  key: 'hr',
  title: 'HR Setup',
  slides: [
    GuideSlide(
      icon: Icons.person_add,
      title: 'Add Your Team',
      body: 'Invite platform team members, assign roles '
          '(admin, support, operations), and set up your '
          'organizational structure.',
      color: Color(0xFFC62828),
    ),
    GuideSlide(
      icon: Icons.badge,
      title: 'Onboarding Workflows',
      body: 'Create customizable onboarding templates with '
          'tax forms, direct deposit, I-9 verification, '
          'and policy acknowledgements.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.health_and_safety,
      title: 'Benefits & Time Off',
      body: 'Set up benefit plans, manage enrollments, and '
          'configure time-off policies for your platform employees.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.schedule,
      title: 'Time Tracking & Documents',
      body: 'Track employee hours, manage HR documents, '
          'and maintain a complete employee record system.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const adminGuide = SetupGuide(
  key: 'admin',
  title: 'Admin Setup',
  slides: [
    GuideSlide(
      icon: Icons.apartment,
      title: 'Business Identity',
      body: 'Set your platform company name, logo, and tagline. '
          'This is the identity that client companies will see.',
      color: Color(0xFF002E5D),
    ),
    GuideSlide(
      icon: Icons.description,
      title: 'Formation & Tax IDs',
      body: 'Complete your business formation, upload incorporation '
          'documents, and register your EIN, NAICS codes, and DUNS number.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.verified_user,
      title: 'Licenses & Insurance',
      body: 'Register with the Secretary of State, obtain required '
          'licenses, and upload your insurance certificates.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.policy,
      title: 'Policies & Compliance',
      body: 'Create service agreements, set pricing policies, '
          'and establish your safety plan. The Setup Wizard '
          'walks you through everything step by step.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const legalGuide = SetupGuide(
  key: 'legal',
  title: 'Legal Setup',
  slides: [
    GuideSlide(
      icon: Icons.description,
      title: 'Business Documents',
      body: 'Upload your EIN letter, business license, articles of '
          'incorporation, and operating agreement to keep everything '
          'in one secure place.',
      color: Color(0xFF6A1B9A),
    ),
    GuideSlide(
      icon: Icons.verified_user,
      title: 'Insurance & Bonding',
      body: 'Add your general liability, commercial auto, workers\' comp, '
          'and umbrella policies. We\'ll track expiration dates for you.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.gavel,
      title: 'Compliance Tracking',
      body: 'Track federal and state compliance requirements. '
          'Each state has different rules — the compliance dashboard '
          'keeps you on top of deadlines.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.handshake,
      title: 'Contracts',
      body: 'Manage service contracts with client companies, vendor '
          'agreements, and any other legal documents your platform needs.',
      color: Color(0xFFE65100),
    ),
  ],
);

const salesGuide = SetupGuide(
  key: 'sales',
  title: 'Sales Setup',
  slides: [
    GuideSlide(
      icon: Icons.sell,
      title: 'Track Your Sales',
      body: 'Manage your sales pipeline, track deals, and monitor '
          'revenue across all your client companies.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.campaign,
      title: 'Marketing',
      body: 'Create and manage marketing campaigns, track ad '
          'performance, and measure your return on investment.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.receipt_long,
      title: 'Quotes & Proposals',
      body: 'Generate professional quotes for prospective clients. '
          'Convert accepted quotes into active contracts seamlessly.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.bar_chart,
      title: 'Sales Analytics',
      body: 'Visualize sales trends, conversion rates, and revenue '
          'growth with built-in dashboards and reports.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const purchasingGuide = SetupGuide(
  key: 'purchasing',
  title: 'Purchasing Setup',
  slides: [
    GuideSlide(
      icon: Icons.receipt_long,
      title: 'Purchase Orders',
      body: 'Create and track purchase orders for supplies, '
          'equipment, and services your platform needs.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.inventory_2,
      title: 'Objects & Assets',
      body: 'Manage your catalog of objects and assets. Track '
          'what you have, what you need, and where it all is.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.store,
      title: 'Vendors',
      body: 'Maintain a directory of your vendors and suppliers. '
          'Compare pricing, track performance, and manage relationships.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.bar_chart,
      title: 'Spending Analytics',
      body: 'Monitor purchasing trends, track spending by category, '
          'and identify opportunities to reduce costs.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const inventoryGuide = SetupGuide(
  key: 'inventory',
  title: 'Inventory Setup',
  slides: [
    GuideSlide(
      icon: Icons.inventory_2,
      title: 'Stock Management',
      body: 'Track cleaning supplies, equipment, and materials '
          'across all your locations and client sites.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.playlist_add,
      title: 'Inventory Requests',
      body: 'Submit and manage requests for new supplies. '
          'Teams can request what they need directly from the app.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.local_shipping,
      title: 'Fulfillment',
      body: 'Track fulfillment of inventory requests. See what\'s '
          'been shipped, delivered, and what\'s still pending.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.bar_chart,
      title: 'Inventory Analytics',
      body: 'Monitor stock levels, usage rates, and reorder points. '
          'Never run out of critical supplies again.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const tasksGuide = SetupGuide(
  key: 'tasks',
  title: 'Tasks',
  slides: [
    GuideSlide(
      icon: Icons.assignment_turned_in,
      title: 'Track What Gets Done',
      body: 'Tasks are the day-to-day work your team performs — '
          'cleaning a room, restocking supplies, completing a route. '
          'Every task ties back to a process and a location.',
      color: Color(0xFF002E5D),
    ),
    GuideSlide(
      icon: Icons.checklist,
      title: 'Assign and Complete',
      body: 'Assign tasks to team members, track them through the '
          'day, and review what was completed. Photos, timecards, '
          'and quality checks all live alongside the task.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.bar_chart,
      title: 'Performance and Quality',
      body: 'Performance and quality scores roll up from individual '
          'tasks so you always know how your team is doing.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const facilitiesGuide = SetupGuide(
  key: 'facilities',
  title: 'Facilities',
  slides: [
    GuideSlide(
      icon: Icons.business,
      title: 'Properties, Buildings, Floors',
      body: 'Model the physical world your team works in. Properties '
          'have buildings, buildings have floors, and floors have '
          'individual locations like rooms, restrooms, and hallways.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.map,
      title: 'Locations and Routes',
      body: 'Tag each location with what it is, what it needs, and '
          'how often. The system uses this to schedule and route work.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.category,
      title: 'Property Types',
      body: 'Schools, offices, hospitals, retail — each property type '
          'has different needs. Configure them once and reuse them '
          'across every property you manage.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const objectsGuide = SetupGuide(
  key: 'objects',
  title: 'Objects',
  slides: [
    GuideSlide(
      icon: Icons.category,
      title: 'Catalog of Things',
      body: 'Objects are the physical items your business deals with — '
          'cleaning chemicals, equipment, restroom fixtures, dispensers, '
          'and consumables. The catalog is your single source of truth.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.science,
      title: 'Elements and Specs',
      body: 'Each object has elements (its components) and specs '
          '(dimensions, capacity, materials). This data feeds into '
          'cost estimates and process planning.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.link,
      title: 'Linked to Processes',
      body: 'Objects are tied to the processes that use them, so '
          'you always know how much of what you need to get the '
          'work done.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const marketplaceGuide = SetupGuide(
  key: 'marketplace',
  title: 'Marketplace',
  slides: [
    GuideSlide(
      icon: Icons.storefront,
      title: 'Buy and Sell',
      body: 'The marketplace lets you browse cleaning products, '
          'equipment, and services from vendors across the platform.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.local_offer,
      title: 'Vendor Listings',
      body: 'Compare prices, read reviews, and find the best deals '
          'on the items your business needs most.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.shopping_bag,
      title: 'One-Click Ordering',
      body: 'Add items directly to your purchasing workflow with '
          'a single tap.',
      color: Color(0xFF2E7D32),
    ),
  ],
);

const processesGuide = SetupGuide(
  key: 'processes',
  title: 'Processes',
  slides: [
    GuideSlide(
      icon: Icons.route,
      title: 'How the Work Gets Done',
      body: 'A process is a documented way of doing something — '
          'how to clean a restroom, how to restock a dispenser, '
          'how to inspect a floor. Each process has steps, materials, '
          'and time estimates.',
      color: Color(0xFF002E5D),
    ),
    GuideSlide(
      icon: Icons.fact_check,
      title: 'Standardize Your Operation',
      body: 'Once a process is defined, your whole team works '
          'the same way. Quality goes up and training time goes down.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.attach_money,
      title: 'Costs Roll Up',
      body: 'Material and labor costs in each process automatically '
          'feed into pricing, quotes, and budget reports.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const schedulingGuide = SetupGuide(
  key: 'scheduling',
  title: 'Scheduling',
  slides: [
    GuideSlide(
      icon: Icons.view_timeline,
      title: 'Plan the Week',
      body: 'Build schedules for your teams across all the properties '
          'you serve. Drag and drop to assign tasks, shifts, and routes.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.event_repeat,
      title: 'Recurring Work',
      body: 'Most cleaning work is recurring. Set up daily, weekly, '
          'or monthly schedules once and let the system generate '
          'tasks automatically.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.notifications_active,
      title: 'Alerts and Conflicts',
      body: 'Get notified about scheduling conflicts, missing coverage, '
          'and team members who are unavailable.',
      color: Color(0xFFE65100),
    ),
  ],
);

const supervisionGuide = SetupGuide(
  key: 'supervision',
  title: 'Supervision',
  slides: [
    GuideSlide(
      icon: Icons.groups,
      title: 'Manage Your Teams',
      body: 'See what your teams are working on right now, who is on '
          'site, and what is being completed across every property.',
      color: Color(0xFFC62828),
    ),
    GuideSlide(
      icon: Icons.handshake,
      title: 'Live Communication',
      body: 'Talk to supervisors and team members in the field through '
          'the built-in messaging, walkie-talkie, and intercom features.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.fact_check,
      title: 'Real-Time Oversight',
      body: 'Track productivity, attendance, and quality scores '
          'in real time so you can act before problems grow.',
      color: Color(0xFF2E7D32),
    ),
  ],
);

const trainingGuide = SetupGuide(
  key: 'training',
  title: 'Training',
  slides: [
    GuideSlide(
      icon: Icons.school,
      title: 'Build Your Library',
      body: 'Upload videos, documents, and quizzes to build a training '
          'library your team can access anytime from their phones.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.workspace_premium,
      title: 'Certifications',
      body: 'Track who has completed what, when certifications expire, '
          'and who needs refresher training.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.quiz,
      title: 'Test Knowledge',
      body: 'Quizzes confirm comprehension and unlock new tasks once '
          'a team member is qualified to perform them.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const qualityGuide = SetupGuide(
  key: 'quality',
  title: 'Quality',
  slides: [
    GuideSlide(
      icon: Icons.auto_awesome,
      title: 'Inspect Your Work',
      body: 'Run quality inspections on completed tasks. Score them, '
          'photograph them, and use the results to coach your team.',
      color: Color(0xFF002E5D),
    ),
    GuideSlide(
      icon: Icons.fact_check,
      title: 'Customer-Visible Reports',
      body: 'Share quality reports with your customers so they can '
          'see exactly what was done and how well.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.trending_up,
      title: 'Improve Over Time',
      body: 'Spot trends, identify struggling team members, and '
          'celebrate teams that consistently deliver excellent work.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const safetyGuide = SetupGuide(
  key: 'safety',
  title: 'Safety',
  slides: [
    GuideSlide(
      icon: Icons.warning_amber,
      title: 'Stay Safe on the Job',
      body: 'Manage hazard analyses, safety data sheets, PPE '
          'requirements, and incident reports — all in one place.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.shield,
      title: 'Job Hazard Analyses',
      body: 'Document the hazards of every process and the controls '
          'you use to mitigate them. Keep your team — and your '
          'insurance carrier — happy.',
      color: Color(0xFF002E5D),
    ),
    GuideSlide(
      icon: Icons.medical_services,
      title: 'Incident Tracking',
      body: 'Report and follow up on every incident. Use the data '
          'to spot patterns and prevent the next one.',
      color: Color(0xFFC62828),
    ),
  ],
);

const occupancyGuide = SetupGuide(
  key: 'occupancy',
  title: 'Occupancy',
  slides: [
    GuideSlide(
      icon: Icons.door_front_door,
      title: 'Track Who Is Where',
      body: 'Monitor real-time occupancy of buildings, floors, and '
          'individual spaces using sensors, badge swipes, or manual '
          'check-ins.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.insights,
      title: 'Demand-Driven Cleaning',
      body: 'Use occupancy data to clean what was actually used, '
          'not what was on the schedule. Save time and supplies.',
      color: Color(0xFF2E7D32),
    ),
    GuideSlide(
      icon: Icons.timeline,
      title: 'Usage Reports',
      body: 'Show customers how their space is really being used '
          'with beautiful, easy-to-read reports.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

const engagementGuide = SetupGuide(
  key: 'engagement',
  title: 'Engagement',
  slides: [
    GuideSlide(
      icon: Icons.headset_mic,
      title: 'Stay Connected',
      body: 'Engagement is your hub for communicating with customers '
          'and tenants — service requests, feedback, satisfaction '
          'surveys, and announcements.',
      color: Color(0xFF1565C0),
    ),
    GuideSlide(
      icon: Icons.feedback,
      title: 'Listen to Feedback',
      body: 'Collect ratings and comments from the people who use '
          'the spaces you clean. Respond quickly and close the loop.',
      color: Color(0xFFE65100),
    ),
    GuideSlide(
      icon: Icons.bar_chart,
      title: 'Engagement Reports',
      body: 'Track satisfaction over time, identify problem areas, '
          'and prove your value to customers with hard numbers.',
      color: Color(0xFF6A1B9A),
    ),
  ],
);

/// All guides, for listing in the menu drawer.
const allGuides = [
  mainGuide,
  tasksGuide,
  facilitiesGuide,
  objectsGuide,
  marketplaceGuide,
  processesGuide,
  schedulingGuide,
  hrGuide,
  supervisionGuide,
  trainingGuide,
  qualityGuide,
  safetyGuide,
  inventoryGuide,
  purchasingGuide,
  occupancyGuide,
  engagementGuide,
  salesGuide,
  legalGuide,
  financeGuide,
  adminGuide,
];

/// Lookup by key.
SetupGuide? guideForKey(String key) {
  for (final g in allGuides) {
    if (g.key == key) return g;
  }
  return null;
}
