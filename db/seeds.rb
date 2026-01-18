# intermediary
Knowledgebase.find_or_initialize_by(short: "intermediary", lang: "de").update!(
  position: 1,
  frontpage: true,
  title: "Vorteile eines Datennetzwerks",
  icon: "people-fill",
  intro: "Erfahren Sie, wie ein Datennetzwerk Vertrauen schafft, Workflows vereinfacht, formalisiert und die Einhaltung regulatorischer Anforderungen unterstützt.",
  link: "/faq/intermediary",
  description: "Die DAO dient als Governance-Kern des Datennetzwerks und erleichert die Formalisierung der workflows zwischen der Gruppe der Datenfreizügigen und daran interessierten Regionen."
)
Knowledgebase.find_or_initialize_by(short: "intermediary", lang: "en").update!(
  position: 1,
  frontpage: true,
  title: "Benefits of a Data Network",
  icon: "people-fill",
  intro: "Learn how a regulated data network builds trust, simplifies and formalizes workflows, and supports compliance with regulatory requirements.",
  link: "/faq/intermediary",
  description: "DAO serves as the governance nucleus of the data network and facilitates the formalisation of workflows between contributors and regional analysts."
)

# provide
Knowledgebase.find_or_initialize_by(short: "provide", lang: "de").update!(
  position: 2,
  frontpage: true,
  title: "Daten beitragen",
  icon: "upload",
  intro: "Hier erfahren Sie, wie Sie Ihre Daten im Datennetzwerk registrieren und beitragen können – vom Datenkatalog über Metadaten bis hin zur Verwaltung von Zugriffsrechten.",
  link: "/faq/provide",
  description: ""
)
Knowledgebase.find_or_initialize_by(short: "provide", lang: "en").update!(
  position: 2,
  frontpage: true,
  title: "Contribute Data",
  icon: "upload",
  intro: "Learn how to register and contribute your data to the data network — data catalogue and metadata to managing access rights.",
  link: "/faq/provide",
  description: ""
)

# access
Knowledgebase.find_or_initialize_by(short: "access", lang: "de").update!(
  position: 3,
  frontpage: true,
  title: "Zugriff auf Daten",
  icon: "download",
  intro: "Entdecken Sie, wie Sie über Suchfunktionen und definierte Schnittstellen Zugang zu relevanten Daten erhalten.",
  link: "/faq/access",
  description: "tbd"
)
Knowledgebase.find_or_initialize_by(short: "access", lang: "en").update!(
  position: 3,
  frontpage: true,
  title: "Access Data",
  icon: "download",
  intro: "Discover how to obtain access to relevant data via search functions and defined interfaces.",
  link: "/faq/access",
  description: "tbd"
)

# use
Knowledgebase.find_or_initialize_by(short: "use", lang: "de").update!(
  position: 4,
  frontpage: true,
  title: "Service verwenden",
  icon: "gear-fill",
  intro: "Lernen Sie die verschiedenen Services kennen, die unser Intermediär anbietet – von Datenverarbeitungsservices bis hin zu analytischen Anwendungen.",
  link: "/faq/use",
  description: ""
)
Knowledgebase.find_or_initialize_by(short: "use", lang: "en").update!(
  position: 4,
  frontpage: true,
  title: "Use Services",
  icon: "gear-fill",
  intro: "Get to know the various services offered by our intermediary—from data processing services to analytical applications.",
  link: "/faq/use",
  description: ""
)

# register
Knowledgebase.find_or_initialize_by(short: "register", lang: "de").update!(
  position: 5,
  frontpage: true,
  title: "Service registrieren",
  icon: "ui-checks-grid",
  intro: "Wenn Sie einen eigenen Service anbieten möchten, erfahren Sie hier, wie Sie diesen registrieren, beschreiben und mit den passenden Datenschutz- und Nutzungsrichtlinien versehen.",
  link: "/faq/register",
  description: ""
)
Knowledgebase.find_or_initialize_by(short: "register", lang: "en").update!(
  position: 5,
  frontpage: true,
  title: "Register a Service",
  icon: "ui-checks-grid",
  intro: "If you want to offer your own service, learn how to register and describe it and attach the appropriate privacy and terms-of-use policies.",
  link: "/faq/register",
  description: ""
)
