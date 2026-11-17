# Vidéo et soumission

## 1. Ce que le règlement demande

D'après la page du Global Student Challenge 2026 :

- Un **dépôt GitHub public**, avec le code et la documentation en anglais, et un README qui présente le titre, le problème, l'approche, l'usage de MATLAB, de Simulink et de l'IA générative, la structure du dépôt et les résultats.
- Une **vidéo de 3 à 5 minutes** contenant : une introduction au problème, une démonstration de l'usage de Simulink, une démonstration de l'usage de l'IA générative. En anglais, ou dans une autre langue avec sous-titres. Mise en ligne sur YouTube avec le tag **#GlobalStudentChallenge2026**.
- Le **formulaire de soumission** de la page du concours, à remplir **avant le 5 mars 2027**, avec le lien du dépôt et celui de la vidéo. Ce n'est pas le formulaire de la page GitHub du sujet.
- Licence du dépôt : MIT ou BSD 2-Clause.

Relisez la page officielle avant de soumettre : les conditions peuvent avoir changé depuis vos captures d'écran du 12 novembre.

---

## 2. Plan de la vidéo (environ 4 minutes 30)

Le texte à dire est proposé en anglais, pour une vidéo en anglais. Adaptez-le à votre façon de parler : un texte récité se voit.

### Séquence 1 — Le problème (0:00 à 0:40)

**À l'écran :** le titre, puis un schéma simple du micro-réseau (soleil, batterie, pile réversible, réservoir, réseau).

> "Green hydrogen is made by electrolysis powered by renewable electricity. But the sun is variable, and the same installation must also supply electricity. The challenge asks for a reversible fuel cell, able to work as an electrolyzer or as a generator, inside a three-phase solar microgrid, and for data-driven recommendations."

### Séquence 2 — Le composant réversible (0:40 à 1:30)

**À l'écran :** le fichier `ReversibleFuelCell.ssc`, en surlignant la ligne `asinh`, puis la figure `polarization.png`.

> "MathWorks' fuel cell and electrolyzer components each block the current in the other direction. I wrote a single Simscape component. The key is an inverted Butler-Volmer equation: the voltage stays continuous when the current crosses zero. I calibrated it on published curves of a modern reversible cell, digitized by image processing: 5 millivolts of error in both modes."

### Séquence 3 — Démonstration Simulink (1:30 à 2:40)

C'est la séquence obligatoire sur Simulink : montrez le logiciel en marche, pas seulement des figures.

**À l'écran :**
1. Ouvrir `MicrogridAverage.slx`, zoomer sur la pile réversible, la batterie, l'onduleur.
2. Lancer la simulation (ou `runMicrogridDemo`).
3. Montrer `microgrid_demo.png` et commenter les trois actes.
4. Montrer en quelques secondes `inverter_fidelity.png`.

> "Here is the three-phase microgrid in Simscape Electrical: a 900-volt DC bus, photovoltaics, a battery, the reversible stack and its hydrogen tank, and a grid-following inverter. When a cloud passes, the stack reverses from electrolyzer to fuel cell through zero current, while the battery covers the transient. 98.7 percent of the load is supplied without the grid. A switching model of the inverter confirms the average model within 0.34 percent, and reveals that the filter needs to be improved."

### Séquence 4 — Résultats sur une année (2:40 à 3:30)

**À l'écran :** `annual_simulation.png`, puis `sizing_study.png`.

> "The same cell equations run hour by hour over a year, with NASA weather data for California and Texas. Without hydrogen, self-sufficiency saturates around 86 percent; with the reversible stack it reaches 95 to 99 percent. In California this is at grid parity if the DOE 2030 cost targets are met. In Texas, electricity is too cheap. The key drivers are the stack cost and the local electricity price, not the physical parameters I had to estimate."

### Séquence 5 — Démonstration de l'IA générative (3:30 à 4:20)

C'est la deuxième séquence obligatoire. Montrez réellement l'outil.

**À l'écran :** une session Claude Code avec le serveur MCP de MATLAB. Par exemple, demandez à l'agent d'exécuter un test ou de calculer la tension à 1 A/cm², et montrez la commande s'exécuter dans MATLAB. Montrez aussi un passage de l'historique Git.

> "I developed this project with an AI agent, Claude, connected to MATLAB through the MATLAB MCP server. The agent wrote and ran the code in my MATLAB session. Every result was executed and tested: there are 58 automated tests. The AI did not generate any data: measurements, weather and costs come from cited sources. The README explains exactly how AI was used."

Soyez prêt à ce que cette séquence soit regardée de près : elle doit montrer un usage réel et maîtrisé.

### Séquence 6 — Conclusion (4:20 à 4:40)

**À l'écran :** les recommandations du README, puis l'adresse du dépôt.

> "One component, one set of equations, three time scales. Hydrogen takes over where batteries stop. The code, models, tests and report are on GitHub."

### Conseils de tournage

- Enregistrez l'écran avec un logiciel de capture (la Xbox Game Bar de Windows, `Windows + G`, suffit).
- Préparez MATLAB avant : `setupProject` déjà lancé, modèles déjà ouverts, figures déjà générées. Ne montrez pas d'attente.
- Grossissez la police de l'éditeur MATLAB et le zoom de Simulink.
- Ajoutez des sous-titres anglais même si vous parlez anglais : ils aident le jury.

---

## 3. Les schémas Simulink pour la vidéo

Les deux modèles enregistrés dans `models/` sont organisés en sous-systèmes nommés, avec des ports nommés et une légende. Ils contiennent un scénario par défaut et tournent dès leur ouverture, après `setupProject`. Ce sont eux qu'il faut montrer.

Pour la séquence Simulink :

- ouvrez `MicrogridAverage.slx` et montrez d'abord le niveau supérieur, qui se lit comme un schéma de principe ;
- double-cliquez sur « Reversible Fuel Cell and Hydrogen Tank » pour montrer la pile réversible et son convertisseur ;
- lancez la simulation avec le bouton Run : les 5 secondes du scénario demandent une à trois minutes de calcul selon la machine ; préparez-la avant l’enregistrement et coupez l’attente au montage.

Ces modèles sont reconstruits par `models/buildPresentationModels.m`. Si vous modifiez un modèle à la main dans Simulink, ce script écrasera vos changements à sa prochaine exécution.

---

## 4. Liste de contrôle avant soumission

**Contenu**

- [ ] Relire la déclaration sur l'usage de l'IA dans le README et le rapport : vous la signez.
- [ ] Confirmer la licence (MIT actuellement, BSD 2-Clause possible).
- [ ] Vérifier les deux références citées de mémoire (Springer 1991, Spencer 1971).
- [ ] Vérifier le coût de la pile par kilowatt dans le DOE Record 20001 (tableau mal extrait).
- [ ] Vérifier le seuil de distorsion de la norme IEEE 1547 si vous le citez à l'oral.

**Dépôt**

- [ ] Supprimer ou déplacer les quatre captures d'écran et le fichier `httpsgithub.commathworksMATLAB-Simu.txt` de la racine du projet.
- [ ] Créer un dépôt GitHub public et y envoyer l'historique.
- [ ] Vérifier sur GitHub que le README s'affiche avec ses figures et ses équations.
- [ ] Sur une autre machine si possible, ou après un redémarrage de MATLAB : cloner le dépôt, lancer `main` et `runAllTests`.

**Vidéo et formulaire**

- [ ] Enregistrer la vidéo (3 à 5 minutes), la mettre en ligne sur YouTube avec le tag #GlobalStudentChallenge2026.
- [ ] Ajouter le lien de la vidéo dans le README.
- [ ] Remplir le formulaire de soumission avant le 5 mars 2027, avec la même adresse e-mail que l'inscription.

**Préparation personnelle**

- [ ] Lire le guide en trois parties.
- [ ] Faire les exercices de la section 12 de la préparation à la défense.
- [ ] Répéter la démonstration en direct sur la machine qui servira.
