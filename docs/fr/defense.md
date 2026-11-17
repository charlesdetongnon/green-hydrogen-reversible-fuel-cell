# Préparation à la défense

Ce document prépare aux questions des examinateurs. Il suppose que vous avez lu le guide en trois parties. Les réponses sont rédigées pour être dites à l'oral : courtes d'abord, détaillées ensuite si on vous relance.

Conseil général : quand vous ne savez pas, dites-le, puis dites comment vous le vérifieriez. Un examinateur respecte une limite reconnue ; il sanctionne une affirmation fausse.

---

## 1. La présentation en deux minutes

> Le sujet demande une pile à combustible réversible en Simscape, intégrée dans un micro-réseau triphasé solaire avec stockage, étudiée à plusieurs niveaux de fidélité, et des recommandations chiffrées.
>
> Les composants existants de MathWorks ne sont pas réversibles : ils bloquent le courant dans l'autre sens. J'ai donc écrit un composant unique, dont la tension reste continue quand le courant passe par zéro, grâce à une forme inversée de l'équation de Butler-Volmer.
>
> Je l'ai calibré sur les courbes publiées d'une cellule réversible moderne, numérisées par traitement d'image : 5 millivolts d'erreur sur 24 points, dans les deux modes.
>
> Le même modèle sert à trois échelles : un onduleur commuté à la microseconde, un micro-réseau moyenné à la seconde, et une simulation heure par heure sur une année, chaque niveau étant vérifié contre le suivant.
>
> Résultat principal : sans hydrogène, l'autosuffisance plafonne vers 86 % ; avec la pile réversible on atteint 95 à 99 %. En Californie, c'est au prix du réseau si les cibles de coût 2030 du DOE sont atteintes ; au Texas, l'électricité est trop bon marché pour que ce soit rentable. Les conclusions dépendent du coût de la pile et du prix local de l'électricité, pas des paramètres physiques que j'ai dû estimer.

---

## 2. Les chiffres à connaître par cœur

| Grandeur | Valeur |
|---|---|
| Tension réversible standard | 1,229 V |
| Tension thermoneutre | 1,481 V |
| Constante de Faraday | 96 485 C/mol |
| Énergie de l'hydrogène (PCS) | 285,8 kJ/mol, soit 39,4 kWh/kg |
| Tension de cellule à 1 A/cm², électrolyse / pile | 1,512 V / 0,719 V |
| Rapport des tensions, définition du DOE | 52,1 % (DOE 2020 : 52 %) |
| Erreur de calibration | 5,3 mV (validation croisée : 7,3 mV) |
| Rendement aller-retour, pile / système | 51,9 % / 47,4 % |
| Électricité par kg d'hydrogène (système) | 46 kWh/kg |
| Puissance de la pile à 1 A/cm², électrolyse / pile | 45,4 kW / 21,6 kW |
| Autosuffisance : solaire seul / + batterie / + hydrogène (Daggett) | 59 % / 72 % / 99 % |
| Plafond sans hydrogène | 86 % (Californie), 82 % (Texas) |
| Coût à 95 % d'autosuffisance, rapport au réseau (Californie) | 1,35 (2020), 1,04 (2030), 0,97 (ultime) |
| Prix de l'électricité 2023, tertiaire | 23,9 ¢/kWh (Californie), 8,8 ¢/kWh (Texas) |
| Coût incrémental de l'hydrogène, Californie, cibles 2030 | 2,7 à 6,6 $/kg |
| Moyenné contre commuté | 0,34 % d'écart, 13 fois plus rapide |
| Distorsion du courant, modèle commuté | 9,3 % |
| Nombre de tests | 56 |

---

## 3. Questions scientifiques et mathématiques

**Q1. Pourquoi deux tensions de référence, 1,229 V et 1,481 V ?**

La première vient de l'énergie libre de Gibbs, la part de l'énergie convertible en travail électrique. La seconde vient de l'enthalpie, l'énergie totale de la réaction. La différence, $T\Delta S$, est forcément échangée sous forme de chaleur. En électrolyse, au-dessus de 1,481 V la cellule dégage de la chaleur, en dessous elle en absorbe.

**Q2. Pourquoi le rendement d'électrolyse dépasse 100 % à faible courant ?**

Parce qu'il est calculé sur le PCS et que la cellule, sous 1,481 V, puise de la chaleur dans son environnement. Cette chaleur n'est pas comptée comme une dépense. Ce n'est pas une violation de la conservation de l'énergie : le bilan complet, chaleur incluse, est fermé. Dans le modèle, la chaleur est même négative à ces points.

**Q3. Pourquoi la tension réversible baisse avec la température ?**

Parce que l'entropie de la réaction est négative dans le sens de la formation de l'eau : $\partial E/\partial T = \Delta S/(2F)$, environ −0,85 mV/K. À 80 °C, cela fait 47 mV de moins qu'à 25 °C. C'est d'ailleurs l'essentiel de l'écart avec les exemples MathWorks, qui gardent 1,229 V.

**Q4. Pourquoi l'électrode à oxygène domine-t-elle les pertes ?**

La réaction à l'oxygène met en jeu quatre électrons et plusieurs étapes intermédiaires ; elle est beaucoup plus lente que celle de l'hydrogène. Son courant d'échange est faible, donc sa surtension d'activation est grande. Dans le modèle, l'activation représente environ 0,28 V en électrolyse et 0,35 V en mode pile à 1 A/cm², soit la plus grosse perte.

**Q5. Pourquoi les paramètres cinétiques diffèrent-ils entre les deux modes ?**

Parce que l'électrode à oxygène fait deux réactions différentes : elle dégage de l'oxygène en électrolyse et en réduit en mode pile. Ce sont deux mécanismes, sur des catalyseurs différents (iridium pour l'un, platine pour l'autre, dans une électrode mixte). La calibration le confirme : le courant d'échange est sept fois plus grand en électrolyse.

**Q6. Pourquoi la teneur en eau de la membrane change-t-elle avec le mode ?**

En électrolyse, la membrane baigne dans l'eau liquide ; en mode pile, elle ne voit que de la vapeur. Une membrane gorgée d'eau liquide conduit mieux. C'est un phénomène connu sous le nom d'effet de Schroeder. Le modèle le traduit par $\lambda = 22$ en électrolyse (supposé) et $\lambda = 10{,}1$ en mode pile (ajusté).

**Q7. Le changement de paramètres à courant nul ne crée-t-il pas de discontinuité ?**

Non. Les deux termes qui changent sont nuls à courant nul : la surtension d'activation (le sinus hyperbolique inverse de zéro vaut zéro) et la surtension ohmique (proportionnelle au courant). Leur valeur est donc la même des deux côtés de zéro. Seule leur pente change, ce qui est physique. Un test le vérifie.

**Q8. D'où vient le facteur 2 dans la loi de Faraday ?**

Une molécule d'hydrogène, c'est deux protons et deux électrons : $\mathrm{H_2 \rightarrow 2H^+ + 2e^-}$. Pour produire une mole d'hydrogène, il faut faire passer deux moles d'électrons, soit $2F$ coulombs.

**Q9. Qu'est-ce que la fuite d'hydrogène et pourquoi compte-t-elle ?**

Un peu d'hydrogène diffuse à travers la membrane sans participer à la réaction électrique. Le débit est proportionnel à la pression et inversement proportionnel à l'épaisseur. À pression ambiante, c'est 0,17 % du courant à 1 A/cm². À 90 bar, c'est 0,28 A/cm², soit 28 %. C'est pourquoi faire fonctionner une pile à membrane fine sous la pression du réservoir effondre le rendement aller-retour à 32 %.

**Q10. Pourquoi l'équation d'Abel-Noble plutôt que les gaz parfaits ?**

À 350 bar, les molécules d'hydrogène occupent une part non négligeable du volume. Le facteur de compressibilité vaut $Z = 1 + pb/RT = 1{,}22$ : un réservoir contient 22 % d'hydrogène de moins que ce qu'annoncerait la loi des gaz parfaits. Ignorer cela surestimerait la capacité de stockage.

**Q11. Comment le régulateur de l'onduleur règle-t-il la tension du bus ?**

Si plus de puissance entre dans le bus qu'il n'en sort, les condensateurs se chargent et la tension monte. Le régulateur de tension augmente alors la consigne de courant actif $i_d$, donc la puissance envoyée au réseau, jusqu'à ce que la tension revienne à 900 V. Le réseau absorbe ainsi automatiquement tout ce que la pile et la batterie ne prennent pas.

**Q12. Pourquoi travailler dans le repère tournant dq ?**

Parce que des grandeurs sinusoïdales à 60 Hz deviennent constantes dans un repère qui tourne à 60 Hz. Un régulateur PI annule alors l'erreur en régime établi, ce qu'il ne sait pas faire sur une consigne sinusoïdale. De plus, si l'axe d est aligné sur la tension, la puissance active vaut $1{,}5\,v_d\,i_d$ et la puissance réactive dépend de $i_q$ seul : les deux se règlent séparément.

---

## 4. Démonstrations à savoir refaire au tableau

### 4.1 De Butler-Volmer à la formule du modèle

L'équation de Butler-Volmer, avec deux électrons et des coefficients de transfert égaux à $\alpha$ dans les deux sens, s'écrit

$$j = j_0\left[e^{\frac{2\alpha F\eta}{RT}} - e^{-\frac{2\alpha F\eta}{RT}}\right] = 2 j_0 \sinh\!\left(\frac{2\alpha F\eta}{RT}\right)$$

On l'inverse :

$$\eta = \frac{RT}{2\alpha F}\,\operatorname{asinh}\!\left(\frac{j}{2 j_0}\right)$$

Quand $j \gg j_0$ : $\operatorname{asinh}(x) = \ln(x + \sqrt{x^2+1}) \approx \ln(2x)$, donc

$$\eta \approx \frac{RT}{2\alpha F}\ln\!\left(\frac{j}{j_0}\right)$$

C'est la loi de Tafel. Avec $\alpha = 0{,}5$ à 80 °C, la pente vaut $0{,}0304 \times \ln 10 = 70$ mV par décade de courant.

### 4.2 Le rendement aller-retour égale le rapport des tensions

Sans fuite, une électrolyse sous tension $V_{EC}$ produit l'hydrogène avec un rendement PCS de $V_{tn}/V_{EC}$, puisque chaque charge $2F$ fournit $2F V_{EC}$ joules pour stocker $\Delta H = 2F V_{tn}$. De même, la pile restitue $2F V_{FC}$ par mole d'hydrogène consommée, soit un rendement $V_{FC}/V_{tn}$. Le produit :

$$\eta_{AR} = \frac{V_{tn}}{V_{EC}}\times\frac{V_{FC}}{V_{tn}} = \frac{V_{FC}}{V_{EC}}$$

La tension thermoneutre disparaît. À 1 A/cm² dans les deux modes : $0{,}719/1{,}512 = 47{,}5\ \%$. C'est pourquoi le DOE définit le rendement aller-retour comme un rapport de tensions.

### 4.3 Le signe de la chaleur

Par cellule et en divisant par le courant :

$$\frac{\dot Q}{I} = V - \frac{\Delta H}{2F} = V - V_{tn}$$

- En électrolyse ($I > 0$) : chaleur dégagée si $V > V_{tn}$, absorbée sinon.
- En mode pile ($I < 0$, $V < V_{tn}$) : le produit de deux négatifs est positif, la chaleur est toujours dégagée.

Une seule formule, le bon signe dans tous les cas.

### 4.4 L'effet de la pression

$$\frac{\partial V_{rev}}{\partial \ln p_{H_2}} = \frac{RT}{2F}$$

Multiplier la pression d'hydrogène par 10 ajoute $0{,}0152 \times 2{,}303 = 35$ mV à 80 °C. Produire l'hydrogène sous 350 bar plutôt qu'à 0,54 bar ajouterait $0{,}0152 \times \ln(350/0{,}539) \approx 0{,}10$ V par cellule, soit environ 6,5 % de tension en plus : c'est la « compression électrochimique ». Elle serait moins chère que le compresseur (8,6 % de l'énergie) si la fuite ne l'annulait pas.

### 4.5 Le facteur d'annuité

Une annuité constante $A$ payée pendant $n$ ans, actualisée au taux $r$, vaut aujourd'hui

$$P = \sum_{k=1}^{n}\frac{A}{(1+r)^k} = A\,\frac{1 - (1+r)^{-n}}{r}$$

d'où

$$A = P\,\frac{r(1+r)^n}{(1+r)^n - 1}$$

Pour 8 % sur 25 ans, le facteur vaut 0,0937 : un investissement de 100 000 $ coûte 9 370 $ par an.

### 4.6 Le réglage de la boucle de courant

Le filtre est une inductance $L$ en série avec une résistance $R$ : sa fonction de transfert est $1/(Ls + R)$. Un régulateur PI s'écrit $k_p + k_i/s = k_p\,(s + k_i/k_p)/s$. En choisissant $k_i/k_p = R/L$, le zéro du régulateur compense le pôle du filtre, et il reste

$$\frac{k_p}{L\,s}$$

un intégrateur pur. La boucle fermée a pour bande passante $k_p/L$. Avec $k_p = L\,\omega_c$, on obtient exactement $\omega_c$, ici $2\pi \times 300 = 1885$ rad/s.

### 4.7 Le minimum théorique de l'électrolyse

$$\frac{285\,800\ \text{J/mol}}{2{,}016\times10^{-3}\ \text{kg/mol}} = 141{,}8\ \text{MJ/kg} = 39{,}4\ \text{kWh/kg}$$

Le système consomme 46 kWh/kg, soit un rendement de 86 % sur le PCS, compression et auxiliaires compris.

---

## 5. Questions sur les algorithmes et les choix de méthode

**Q13. Pourquoi un modèle semi-empirique et pas un modèle détaillé ?**

Parce qu'un modèle détaillé, avec écoulements et transport d'eau, a des dizaines de paramètres que je ne peux pas mesurer. Je l'aurais ajusté sans pouvoir le valider. Le modèle retenu est le plus détaillé que les données disponibles permettent de calibrer honnêtement, et il reste assez rapide pour simuler une année.

**Q14. Comment avez-vous choisi le nombre de paramètres ajustés ?**

Par validation croisée « un point retiré » : j'ai comparé six jeux de paramètres, de 3 à 7. J'ai retenu celui dont l'erreur de prédiction sur les points retirés était la plus faible, en écartant ceux dont les paramètres ne se distinguaient pas (conditionnement de la jacobienne supérieur à 5 000). Le jeu à 7 paramètres a été écarté pour cette raison.

**Q15. Pourquoi ajuster le logarithme des courants d'échange ?**

Parce qu'ils varient sur plusieurs ordres de grandeur. Sur l'échelle naturelle, un pas de l'algorithme qui convient à $10^{-4}$ est énorme pour $10^{-6}$. Sur l'échelle logarithmique, tous les ordres de grandeur sont traités pareillement.

**Q16. Pourquoi une gestion d'énergie par règles et pas une optimisation ?**

Trois raisons : elle n'a pas besoin de prévision météo, elle est transparente, et la toolbox de commande prédictive est expirée sur ma licence. J'ai comparé deux variantes, batterie d'abord et pile d'abord, qui encadrent le compromis principal. Une commande optimisée est la première perspective d'amélioration.

**Q17. Pourquoi « perturber et observer » pour le suivi du point de puissance maximale ?**

C'est l'algorithme le plus simple et le plus utilisé. Son défaut connu est une petite oscillation autour du maximum et un suivi imparfait lors de variations rapides. Pour un modèle de système, c'est suffisant ; l'étude ne porte pas sur la performance du suivi.

**Q18. Pourquoi l'année simulée est-elle « bouclée » ?**

Sans bouclage, le réservoir démarre à moitié plein et finit à 14 % : 42 kg d'hydrogène gratuits auraient été consommés, ce qui gonfle l'autosuffisance. La version bouclée relance la simulation en repartant du niveau final jusqu'à ce que début et fin coïncident. L'année décrite peut alors se répéter indéfiniment.

**Q19. Pourquoi un coût « incrémental » de l'hydrogène ?**

Parce que l'installation produit d'abord de l'électricité. Attribuer tout son coût à l'hydrogène serait arbitraire. Je mesure donc ce que coûte en plus l'objectif de production, par rapport à la même installation sans soutirage.

---

## 6. Questions sur MATLAB, Simulink et les toolboxes

**Q20. Qu'est-ce que le Simscape Language apporte par rapport à un bloc MATLAB Function ?**

On écrit des équations, pas un algorithme. Simscape les résout simultanément avec celles des autres composants, gère les unités, et connecte le composant à des domaines physiques (électrique, thermique) avec des lois de conservation. Un bloc MATLAB Function calcule une sortie à partir d'une entrée ; il ne peut pas être branché dans un circuit.

**Q21. Que fait `sscbuild` ?**

Il compile les fichiers `.ssc` d'un paquet en une bibliothèque Simulink, ici `greenH2_lib.slx`, dont les blocs ont une boîte de dialogue générée automatiquement à partir des paramètres déclarés.

**Q22. Pourquoi le solveur `ode23t` ?**

C'est un solveur pour systèmes raides, où coexistent des dynamiques très rapides et très lentes, typiques des circuits électriques et des systèmes algébro-différentiels de Simscape. Il est recommandé par MathWorks pour les modèles Simscape.

**Q23. Pourquoi un retard d'un pas après chaque loi de commande ?**

Pour représenter le temps de calcul d'un vrai contrôleur numérique, et pour casser la boucle algébrique entre la sortie de la commande et les mesures du circuit, qui seraient sinon calculées au même instant.

**Q24. Pourquoi les lois de commande sont-elles des fonctions séparées ?**

Pour pouvoir les tester sans Simulink : les tests vérifient par exemple que la boucle à verrouillage de phase converge vers 60 Hz, ou que la gestion d'énergie respecte les limites du réservoir. Le bloc Simulink ne fait qu'appeler la fonction en conservant son état dans une variable `persistent`.

**Q25. Quelles toolboxes sont nécessaires ?**

Simulink, Simscape, Simscape Electrical et Optimization Toolbox. Image Processing Toolbox n'est utile que pour refaire la numérisation. Plusieurs toolboxes utiles (Stateflow, Simscape Battery, commande prédictive) étaient expirées, ce qui a orienté certains choix.

**Q26. Comment vérifiez-vous qu'un modèle Simscape est correctement résolu ?**

De trois façons : en comparant le composant à son équivalent MATLAB (1 µV d'écart), en vérifiant que les bilans de matière et d'énergie se ferment, et en comparant les niveaux de fidélité entre eux.

---

## 7. Questions sur les résultats et la validation

**Q27. Votre modèle est-il validé ?**

Il est vérifié et comparé, pas validé expérimentalement. Vérifié : 56 tests, bilans fermés, accord entre implémentations. Comparé : à la thermodynamique de la NASA (0,6 mV), à l'état de l'art du DOE (52,1 contre 52 %), aux courbes publiées (5,3 mV), aux exemples MathWorks. Il manque une confrontation à une vraie cellule mesurée à plusieurs températures.

**Q28. Pourquoi 42 mV d'écart avec les exemples MathWorks ?**

Surtout parce que ma tension réversible tient compte de la température (−47 mV à 80 °C) et pas la leur. Viennent ensuite l'activité de l'eau (liquide chez moi, vapeur chez eux) et l'hydratation de la membrane (dynamique chez eux). Les formes des courbes sont les mêmes.

**Q29. L'article annonce 56 % de rendement ; votre modèle donne 47,5 % au même point. Contradiction ?**

Non : ce ne sont pas les mêmes définitions. Le rapport des tensions, mesuré sur la même figure de l'article, vaut bien 47,5 %. L'écart avec 56 % est constant, d'un facteur 1,18, qui est le rapport entre PCS et PCI. L'article semble donc calculer le rendement de la pile sur le PCI. C'est mon interprétation ; je la présente comme telle. Ce qui compte : à définition égale, le modèle et la mesure concordent.

**Q30. Pourquoi faire confiance à des données numérisées ?**

Parce que la numérisation a été vérifiée de deux façons indépendantes : les courants retrouvés tombent à 2 mA/cm² près sur la grille de mesure, et les rendements relus sur la figure retrouvent ceux écrits dans le texte (56,2 contre 56,4 %). La résolution est d'environ 4 mV par pixel, soit moins que l'erreur d'ajustement.

**Q31. Le modèle moyenné est-il fiable ?**

Pour la puissance, oui : il reproduit le courant fondamental du modèle commuté à 0,34 % près. Pour la qualité du courant, non : il ne voit pas l'ondulation de découpage. C'est précisément pourquoi il y a deux niveaux.

**Q32. Comment savez-vous que le modèle annuel est juste ?**

Je l'ai rejoué sur une journée dans le modèle Simscape détaillé, avec la même séquence de courant. Énergies identiques à 0,001 %, hydrogène consommé à 0,6 %. L'écart est expliqué : la fuite d'hydrogène pendant les 14 heures d'arrêt, que le modèle annuel néglige.

**Q33. Pourquoi l'autosuffisance plafonne-t-elle sans hydrogène ?**

Parce que la batterie stocke pour quelques heures. Elle couvre les nuits, pas les journées nuageuses consécutives ni l'hiver. Le réservoir, lui, se remplit au printemps et se vide en hiver : c'est du stockage saisonnier.

**Q34. Pourquoi l'arrêt à froid est-il préférable ?**

La constante de temps thermique de la pile est de 30 minutes. Après deux heures d'arrêt, elle est presque froide. Il coûte donc moins cher de la réchauffer à chaque démarrage (0,4 MWh par an) que de la maintenir chaude en permanence (9,1 MWh par an). Ce résultat dépend des paramètres thermiques estimés, mais l'écart est d'un facteur vingt.

---

## 8. Critiques probables et réponses

**« Ce n'est qu'un ajustement de courbe. »**

Non. La structure du modèle est physique : chaque terme a une origine (Nernst, Butler-Volmer, Ohm, transport), et le modèle prédit correctement ce qu'il n'a pas vu. La tension réversible n'est pas ajustée et concorde avec la NASA à 0,6 mV. Le rapport de tensions du DOE n'a pas servi à l'ajustement et concorde. Et 24 points pour 6 paramètres laissent 18 degrés de liberté.

**« Vous avez supposé les conditions de la mesure. »**

Oui, la pression et l'humidité ne sont pas données dans l'article. J'ai supposé une pression ambiante et des gaz saturés en vapeur, ce qui est la pratique courante pour ce type de test. C'est écrit dans le code et dans le rapport.

**« Vos paramètres thermiques sont inventés. »**

Ils sont estimés, et je le dis. L'analyse de sensibilité montre qu'en les multipliant ou divisant par deux, le coût de l'énergie bouge de moins de 0,1 %. Les conclusions n'en dépendent pas.

**« Vos coûts mélangent des sources et des années différentes. »**

C'est vrai et c'est signalé. Le coût de la batterie est celui d'une grande installation, celui du réservoir date de 2012. La sensibilité montre que ni l'un ni l'autre ne change le classement : le coût de la pile, le taux d'actualisation et le coût du solaire dominent.

**« Le réseau est idéal. »**

Oui. Un réseau avec impédance rendait le système singulier dans ma configuration, et l'étude porte sur le partage d'énergie, pas sur la stabilité du réseau. C'est la deuxième perspective d'amélioration.

**« 9,3 % de distorsion, c'est inacceptable. »**

Exactement, et c'est un résultat du modèle commuté : il montre que le filtre inductif simple est insuffisant. Presque toute la distorsion est à 10 kHz, ce qui désigne le filtre et non la commande. La solution classique est un filtre LCL.

**« Votre optimum n'en est pas un. »**

C'est vrai : la meilleure configuration est au bord de la grille pour le réservoir, et la taille de la pile n'a pas varié. Je présente une exploration, pas une optimisation. Les tendances (plafond à 86 %, effet du prix local, effet du coût de la pile) sont robustes ; les tailles exactes ne le sont pas.

**« Le coût de l'hydrogène au Texas est faussé. »**

Il est surestimé, oui : les configurations retenues améliorent aussi l'alimentation électrique, et ce gain est imputé à l'hydrogène. Je le signale. La conclusion qualitative reste : au Texas, l'électricité est trop bon marché.

**« La soumission de 2022 avait déjà fait ce travail. »**

Elle utilise deux composants séparés, un micro-réseau continu sans batterie, à température fixe, sans étude économique. J'apporte un composant unique et réversible, la thermique, le triphasé, trois niveaux de fidélité vérifiés entre eux, et une étude économique sourcée. J'ai aussi relevé que son équation de débit d'hydrogène omet le facteur 2 de Faraday ; je l'ai vérifié par le calcul, pas en exécutant son modèle.

---

## 9. Questions sur l'usage de l'IA

C'est le thème du concours : attendez-vous à des questions. Le règlement exige que vous compreniez et puissiez expliquer tout ce que vous soumettez.

**Q35. Comment avez-vous utilisé l'IA ?**

Répondez avec exactitude, comme dans le README : un agent (Claude, via Claude Code et le serveur MCP de MATLAB) a rédigé le code, les modèles, les tests et la documentation, et les a exécutés dans MATLAB. Vous avez dirigé : choix du sujet, de la technologie, du pays, validation de chaque étape, décisions sur les questions ouvertes.

**Q36. Comment savez-vous que le code de l'IA est juste ?**

Rien n'a été accepté sans exécution. Chaque étape a été vérifiée par des tests (56), des bilans fermés, et des comparaisons indépendantes. Plusieurs erreurs ont été trouvées ainsi et corrigées : un capteur branché à l'envers, des paramètres mal lus dans l'exemple MathWorks, un journal de simulation tronqué.

**Q37. L'IA a-t-elle inventé des données ?**

Non. Les mesures viennent de documents cités, la météo de la NASA, les coûts du DOE, du NREL et de l'EIA. Quand une valeur n'avait pas de source, elle est marquée comme hypothèse. Deux références de la bibliographie ont été citées de mémoire et doivent être vérifiées ; c'est signalé.

**Q38. Expliquez-moi cette ligne de code.**

C'est la question décisive. Entraînez-vous sur les passages suivants, que vous devez pouvoir commenter sans notes :

1. Dans `ReversibleFuelCell.ssc` : la ligne `v_act = ...asinh(...)`, la ligne `j0 = if ge(j, 0), ...`, et l'équation `nH2 == N_cell * A_cell * (j - j_cross) / (2*F)`.
2. Dans `urfc.cellModel` : le masque `isEC = j >= 0` et son usage.
3. Dans `microgrid.inverterControlStep` : la transformation de Park et les quatre étapes.
4. Dans `microgrid.emsStep` : les quatre règles.
5. Dans `econ.evaluate` : le calcul de la durée de vie de la pile.

**Q39. Qu'avez-vous appris, vous, dans ce projet ?**

Préparez une réponse personnelle et sincère. Pistes : la physique des piles réversibles, la différence entre vérifier et valider, la démarche de calibration, la lecture critique des sources, l'importance des définitions de rendement.

---

## 10. Limites, améliorations et perspectives

Si on vous demande « que feriez-vous avec six mois de plus ? », dans cet ordre :

1. **Mesurer une vraie cellule** à plusieurs températures et pressions, pour identifier l'effet de la température et valider expérimentalement.
2. **Filtre LCL et impédance du réseau**, pour respecter les normes de raccordement et étudier l'îlotage.
3. **Vieillissement** en fonction des heures et des démarrages : il changerait la comparaison entre stratégies.
4. **Gestion d'énergie optimisée** avec prévision, et mesure du gain par rapport aux règles.
5. **Vraie optimisation du dimensionnement**, taille de pile comprise, sur plusieurs années météo, avec tarifs horaires et aides publiques.

---

## 11. Démonstration en direct

Si on vous demande de montrer le projet :

1. Ouvrir MATLAB dans le dossier du projet, taper `main`. En moins de trois minutes, quatre figures apparaissent.
2. Ouvrir `models/MicrogridAverage.slx` après `setupProject`, et montrer le bloc de la pile réversible et sa boîte de dialogue.
3. Taper `runAllTests` si le temps le permet (environ quatre minutes).
4. Montrer `urfc.cellModel(1, 353.15, 0.539, 0.539, urfc.lbnlParameters())` et commenter les quatre termes de la tension.

Testez cette démonstration avant la défense, sur la machine qui servira.

---

## 12. Exercices pour vous entraîner

1. Recalculez à la main la tension réversible à 60 °C et 30 bar d'hydrogène, puis vérifiez avec `urfc.cellModel`.
2. Changez $\alpha$ de 0,5 à 0,7 dans `lbnlParameters`, relancez `calibrateModernUrfc` et expliquez ce qui change.
3. Dans `longterm.config`, passez la stratégie à `"urfcFirst"` et expliquez la différence d'autosuffisance et de cycles de batterie.
4. Dans `econ.costData`, changez le prix de l'électricité californienne et trouvez le prix à partir duquel la configuration à 95 % devient rentable aux coûts 2030.
5. Expliquez, sans regarder, pourquoi la courbe de polarisation passe par zéro sans rupture.
