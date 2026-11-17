# Guide pédagogique — Partie 1 : comprendre le problème et la physique

Ce guide explique tout le projet, de l'énoncé jusqu'aux résultats, pour que vous puissiez le refaire, le modifier et le défendre seul. Il est en trois parties :

1. **Partie 1 (ce fichier)** : le problème, les ressources, la physique, les choix de méthode.
2. **[Partie 2](guide_2_construction.md)** : la construction dans MATLAB et Simulink, fichier par fichier.
3. **[Partie 3](guide_3_resultats.md)** : les résultats, la validation, les limites, la conclusion.

Tous les nombres donnés ici sortent de MATLAB. Quand une valeur est une hypothèse et non une mesure, c'est dit.

---

## 1. Présentation du projet

### 1.1 Le contexte

L'hydrogène « vert » est produit par électrolyse de l'eau : on fait passer un courant électrique dans l'eau, qui se sépare en hydrogène et en oxygène. Si l'électricité vient du soleil ou du vent, aucun gaz à effet de serre n'est émis. Aujourd'hui, la plus grande partie de l'hydrogène est fabriquée à partir de gaz naturel, ce qui émet du CO₂.

La difficulté est double. Le soleil ne brille pas à la demande, donc l'électrolyseur ne peut pas tourner en continu. Et la même installation doit aussi alimenter des consommateurs en électricité.

### 1.2 Ce que demande l'énoncé

Le sujet n° 204 de MathWorks, « Green Hydrogen Production », demande cinq choses :

1. Écrire en **Simscape Language** le modèle d'une **pile à combustible réversible**, capable de fonctionner dans les deux sens : comme électrolyseur (électricité → hydrogène) ou comme générateur (hydrogène → électricité).
2. L'intégrer dans un **micro-réseau triphasé** avec du solaire et du stockage.
3. Construire des modèles de **plusieurs niveaux de fidélité** : de la commutation des transistors (microsecondes) à la réponse du système sur des jours ou des semaines, en passant par la thermique.
4. Calculer les **rendements et les puissances** pour plusieurs scénarios d'exploitation.
5. En tirer des **recommandations chiffrées** pour l'industrie et pour les pouvoirs publics.

### 1.3 La réponse apportée, en une phrase

Un seul modèle de cellule réversible, calibré sur des mesures publiées, est utilisé à trois échelles de temps (la microseconde, la seconde, l'année), et sert à dimensionner et chiffrer un micro-réseau solaire pour deux sites américains.

### 1.4 Vos décisions

Trois choix viennent de vous : la technologie (**PEM réversible**), le pays d'étude (**États-Unis**), et la participation en solo. Tout le reste découle de l'énoncé et des données disponibles.

---

## 2. Analyse des ressources

### 2.1 Le dépôt GitHub du sujet

Le dépôt ne contient qu'un énoncé. Il n'y a ni script, ni modèle, ni jeu de données. Il renvoie à quatre ressources MathWorks et à une soumission antérieure. Tout était donc à construire.

### 2.2 Les exemples MathWorks

| Exemple | Ce qu'il contient | Ce qu'on en a tiré |
|---|---|---|
| PEM Fuel Cell System | Pile PEM complète avec circuits de gaz, humidification, refroidissement (plus de 1 000 blocs) | Les équations de la cellule et un point de comparaison |
| PEM Electrolysis System | Électrolyseur PEM complet | Idem, pour l'autre sens |
| Solar Power Inverter | Onduleur solaire | Idées pour la commande |
| Battery Pack Design | Modèles de batterie | Non utilisé (licence expirée) |

Ces deux premiers exemples contiennent chacun un composant en Simscape Language, `FuelCell.ssc` et `Electrolyzer.ssc`. Leur physique est presque identique, mais chacun **bloque le courant dans l'autre sens**. Dans le fichier de la pile, on lit :

```
i_cell = if le(i, 0), -i/area_cell else 0 end;
```

Autrement dit : si le courant change de signe, la densité de courant est forcée à zéro. C'est exactement le verrou à lever pour obtenir un composant réversible.

### 2.3 La soumission de 2022

Un étudiant brésilien avait déjà traité ce sujet. Son travail a été lu, pas réutilisé. Trois constats :

- Il utilise **deux composants séparés**, un par mode, commutés par un signal. Ce n'est pas un composant réversible unique.
- Son micro-réseau est en **courant continu**, sans batterie, à température fixe.
- Son équation de débit d'hydrogène est `mmH2*N_cells*i/F`. Il manque le facteur 2 de la loi de Faraday (voir section 3.6). La production d'hydrogène y est donc surestimée d'un facteur 2.

### 2.4 Les licences MATLAB

Sur votre machine, Simulink, Simscape, Simscape Electrical et Optimization Toolbox fonctionnent. En revanche Simscape Battery, Simscape Fluids, Stateflow et Model Predictive Control sont expirés. Cela a orienté plusieurs choix : la gestion d'énergie est écrite en fonctions MATLAB plutôt qu'en Stateflow, et la batterie est celle de Simscape Electrical.

### 2.5 Le règlement sur l'IA

Le concours autorise et encourage l'IA générative, à trois conditions : dire comment elle a été utilisée, tester tout le code, et **comprendre ce qu'on soumet**. Un travail « non compris » est refusé. Ce guide existe pour cette troisième condition.

---

## 3. Fondements théoriques

Cette section est la plus importante pour la défense. Chaque équation du composant y est expliquée, puis vérifiée sur un exemple numérique.

### 3.1 La réaction

Une cellule PEM est faite de deux électrodes séparées par une membrane qui laisse passer les protons mais pas les électrons. La réaction globale est

$$\mathrm{H_2 + \tfrac{1}{2}O_2 \rightleftharpoons H_2O}$$

- De gauche à droite, c'est une **pile à combustible** : l'hydrogène et l'oxygène forment de l'eau et la cellule fournit du courant.
- De droite à gauche, c'est un **électrolyseur** : on fournit du courant et l'eau se décompose.

Chaque molécule d'hydrogène met en jeu **deux électrons**. Ce chiffre 2 revient partout.

### 3.2 Deux tensions à connaître par cœur

**La tension réversible, 1,229 V.** C'est la tension de la cellule à l'équilibre, sans courant, à 25 °C et 1 bar, avec de l'eau liquide. Elle vient de l'énergie libre de Gibbs de la réaction, $\Delta G = -237{,}1$ kJ/mol :

$$E^0 = \frac{-\Delta G}{2F} = \frac{237\,100}{2 \times 96\,485} = 1{,}229\ \text{V}$$

où $F = 96\,485$ C/mol est la constante de Faraday (la charge d'une mole d'électrons).

**La tension thermoneutre, 1,481 V.** Elle vient de l'enthalpie de la réaction, $\Delta H = -285{,}8$ kJ/mol, qui est aussi le pouvoir calorifique supérieur (PCS) de l'hydrogène :

$$V_{tn} = \frac{-\Delta H}{2F} = \frac{285\,800}{2 \times 96\,485} = 1{,}481\ \text{V}$$

Pourquoi deux tensions ? Parce que toute l'énergie chimique ($\Delta H$) ne peut pas devenir de l'électricité : une partie ($T\Delta S$) est forcément de la chaleur. La tension thermoneutre sert de repère pour la chaleur :

- un électrolyseur qui travaille **au-dessus** de 1,481 V dégage de la chaleur ; en dessous, il en absorbe ;
- une pile travaille toujours en dessous de 1,229 V, donc dégage toujours de la chaleur.

### 3.3 La tension de cellule : une somme de quatre termes

Convention de signe du projet : la densité de courant $j$ (en A/cm²) est **positive en électrolyse** et **négative en mode pile**.

$$V = V_{rev} + \eta_{act} + \eta_{ohm} + \eta_{conc}$$

Les trois derniers termes sont des pertes, appelées surtensions. **Chacune a le signe du courant.** En électrolyse ($j > 0$) elles s'ajoutent : il faut plus de 1,23 V pour produire de l'hydrogène. En mode pile ($j < 0$) elles se retranchent : la cellule fournit moins de 1,23 V. C'est cette idée simple qui permet d'écrire un seul jeu d'équations pour les deux modes.

### 3.4 Terme 1 : la tension réversible (équation de Nernst)

$$V_{rev} = 1{,}229 - 8{,}5\times10^{-4}\,(T - 298{,}15) + \frac{RT}{2F}\ln\!\left(p_{H_2}\sqrt{p_{O_2}}\right)$$

- Le deuxième terme dit que la tension réversible **baisse quand la température monte** (0,85 mV par kelvin).
- Le troisième terme dit qu'elle **monte avec la pression** des gaz. Il faut plus de tension pour produire de l'hydrogène sous pression, et on en récupère plus en le consommant sous pression.

**Exemple chiffré**, aux conditions de calibration : 80 °C (353,15 K), pressions partielles d'hydrogène et d'oxygène de 0,539 bar (pression ambiante, moins la vapeur d'eau).

- Effet de température : $1{,}229 - 0{,}00085 \times 55 = 1{,}1823$ V
- Facteur $RT/2F = 8{,}314 \times 353{,}15 / (2 \times 96\,485) = 0{,}01522$ V
- Effet de pression : $0{,}01522 \times \ln(0{,}539^{1{,}5}) = 0{,}01522 \times (-0{,}927) = -0{,}0141$ V
- **Total : 1,1681 V**

**Vérification indépendante.** La NASA a calculé cette tension à partir de tables thermodynamiques pour deux conditions. Notre formule donne 1,2193 V là où la NASA trouve 1,219 V, et 1,2626 V contre 1,262 V. L'écart est inférieur à 0,6 mV, sans aucun paramètre ajusté.

### 3.5 Terme 2 : la surtension d'activation

Pour qu'une réaction électrochimique avance, il faut franchir une barrière d'énergie. Cela coûte de la tension, surtout à l'électrode à oxygène, qui est lente. La loi qui relie courant et surtension est celle de Butler-Volmer. Dans sa forme symétrique, elle s'inverse exactement :

$$\eta_{act} = \frac{RT}{2\alpha F}\,\operatorname{asinh}\!\left(\frac{j}{2 j_0}\right)$$

- $j_0$ est la **densité de courant d'échange** : plus elle est grande, plus la réaction est facile.
- $\alpha$ est le **coefficient de transfert**, fixé à 0,5.
- $\operatorname{asinh}$ est le sinus hyperbolique inverse.

**Pourquoi cette forme est la clé du projet.** Le sinus hyperbolique inverse a trois propriétés :

1. Il vaut **zéro en zéro** : pas de surtension sans courant.
2. Il est **impair** : $\operatorname{asinh}(-x) = -\operatorname{asinh}(x)$. La surtension change de signe avec le courant, automatiquement.
3. Pour $x$ grand, $\operatorname{asinh}(x) \approx \ln(2x)$. On retrouve donc la **loi de Tafel** $\eta = \frac{RT}{2\alpha F}\ln(j/j_0)$ utilisée par MathWorks.

Les exemples MathWorks utilisent directement la loi de Tafel, qui n'est pas définie à courant nul (le logarithme de zéro n'existe pas). C'est pourquoi ils doivent couper le courant à zéro. Avec le sinus hyperbolique inverse, la courbe passe par zéro sans rupture.

Les valeurs de $j_0$ sont différentes dans les deux modes, car l'électrode à oxygène ne se comporte pas de la même façon quand elle produit de l'oxygène et quand elle en consomme. Comme le terme vaut zéro à $j = 0$, changer de paramètres à cet endroit ne crée aucun saut.

En mode pile, $j_0$ dépend aussi de la pression d'oxygène : $j_0 = j_{0,FC}\,p_{O_2}^{\gamma}$ avec $\gamma = 0{,}75$. C'est ce qui distingue le fonctionnement à l'oxygène pur du fonctionnement à l'air.

**Exemple chiffré**, en électrolyse à 1 A/cm², avec $j_0 = 1{,}009\times10^{-4}$ A/cm² :

- $RT/(2\alpha F) = 0{,}01522/0{,}5 = 0{,}03043$ V
- $\operatorname{asinh}(1/(2 \times 1{,}009\times10^{-4})) = \operatorname{asinh}(4955) = 9{,}201$
- **$\eta_{act} = 0{,}2800$ V**

### 3.6 Terme 3 : la surtension ohmique

C'est la loi d'Ohm : $\eta_{ohm} = R \times j$. La résistance a deux parts : la membrane et les contacts.

$$R = \frac{t_m}{\sigma} + R_c$$

$t_m$ est l'épaisseur de la membrane (50,8 µm pour le Nafion 212) et $\sigma$ sa conductivité, donnée par la corrélation de Springer :

$$\sigma = (0{,}005139\,\lambda - 0{,}00326)\,\exp\!\left[1268\left(\frac{1}{303}-\frac{1}{T}\right)\right]$$

$\lambda$ est la **teneur en eau** de la membrane : une membrane humide conduit bien, une membrane sèche conduit mal. Dans notre modèle, $\lambda$ dépend du mode : 22 en électrolyse (la membrane baigne dans l'eau liquide), 10,1 en mode pile (elle n'est en contact qu'avec de la vapeur). C'est la calibration qui a révélé ce besoin : sans cela, les pentes des deux courbes ne pouvaient pas être reproduites ensemble.

**Exemple chiffré**, en électrolyse à 1 A/cm² :

- $\sigma = (0{,}005139 \times 22 - 0{,}00326) \times e^{0{,}592} = 0{,}1098 \times 1{,}808 = 0{,}1985$ S/cm
- Membrane : $0{,}00508 / 0{,}1985 = 0{,}0256\ \Omega\cdot$cm²
- Contacts : $0{,}0374\ \Omega\cdot$cm²
- **$\eta_{ohm} = 0{,}0630$ V**

### 3.7 Terme 4 : la surtension de concentration

À fort courant, les réactifs n'arrivent plus assez vite aux électrodes. Il existe un courant limite $j_L$ :

$$\eta_{conc} = -\operatorname{sign}(j)\,\frac{RT}{2F}\ln\!\left(1 - \frac{|j|}{j_L}\right)$$

Quand $|j|$ approche $j_L$, le logarithme plonge et la tension s'effondre. Pour éviter un calcul impossible, le modèle remplace la courbe par une droite au-delà de 99,9 % du courant limite. En mode pile, $j_L$ est proportionnel à la pression d'oxygène : à l'air, il y a cinq fois moins d'oxygène, donc un courant limite cinq fois plus bas.

En électrolyse à 1 A/cm², ce terme est négligeable : 0,0008 V.

### 3.8 Le total, vérifié

| Terme | Électrolyse, +1 A/cm² | Pile, −1 A/cm² |
|---|---|---|
| Réversible | 1,1681 V | 1,1681 V |
| Activation | +0,2800 V | −0,3526 V |
| Ohmique | +0,0630 V | −0,0951 V |
| Concentration | +0,0008 V | −0,0017 V |
| **Tension de cellule** | **1,5120 V** | **0,7188 V** |

Ce tableau est exactement ce que calcule la fonction `urfc.cellModel`. Vous pouvez le refaire à la main ou taper dans MATLAB :

```matlab
p = urfc.lbnlParameters();
m = urfc.cellModel(1, 353.15, 0.539, 0.539, p)
```

Remarquez que la pile perd plus en activation (0,35 V contre 0,28 V) et en résistance (0,095 V contre 0,063 V). C'est la raison physique du rendement aller-retour limité.

### 3.9 La loi de Faraday et la fuite d'hydrogène

Le débit d'hydrogène est proportionnel au courant. Pour $N$ cellules de surface $A$ :

$$\dot n_{H_2} = \frac{N\,A\,(j - j_x)}{2F}$$

Le **2** au dénominateur vient des deux électrons par molécule. C'est lui qui manque dans la soumission de 2022.

**Exemple :** 100 cellules de 300 cm² à 1 A/cm² produisent $100 \times 300 / (2 \times 96\,485) = 0{,}155$ mol/s, soit 1,13 kg d'hydrogène par heure.

$j_x$ est la **fuite** : un peu d'hydrogène traverse la membrane sans produire de courant. Elle est proportionnelle à la pression d'hydrogène et inversement proportionnelle à l'épaisseur de la membrane :

$$j_x = \frac{2F\,\psi\,p_{H_2}}{t_m}$$

À pression ambiante, elle vaut 0,0017 A/cm², soit 0,17 % du courant à 1 A/cm². À 350 bar, elle serait 650 fois plus grande. C'est pourquoi le modèle déconseille de mettre la pile à la pression du réservoir.

Une seule formule sert aux deux modes : en électrolyse la fuite diminue la production, en mode pile elle augmente la consommation.

### 3.10 La chaleur

La chaleur dégagée est la différence entre la puissance électrique et la puissance chimique stockée :

$$\dot Q = V I - \dot n_{H_2}\,\Delta H$$

Cette formule unique donne le bon signe dans les deux modes, et garantit que le bilan d'énergie se ferme exactement.

**Exemple :** en mode pile à 1 A/cm², la cellule dégage 0,76 W/cm², alors qu'elle ne fournit que 0,72 W/cm² d'électricité. Plus de la moitié de l'énergie de l'hydrogène part en chaleur. En électrolyse à 1 A/cm², elle ne dégage que 0,03 W/cm², car 1,512 V est juste au-dessus de la tension thermoneutre.

### 3.11 Les rendements

Sur la base du PCS :

- **Électrolyse :** énergie chimique produite / énergie électrique consommée. À 1 A/cm² : 97,8 %.
- **Pile :** énergie électrique produite / énergie chimique consommée. À 0,5 A/cm² : 53,0 %.
- **Aller-retour :** le produit des deux, 51,9 %.

Un raccourci utile : le rendement aller-retour est à peu près le rapport des tensions, $0{,}788 / 1{,}512 = 52{,}1\ \%$. C'est la définition qu'utilise le DOE américain.

**Attention à un piège.** L'article qui a servi à la calibration annonce 56 % à 1 A/cm². Le rapport des tensions à ce point ne vaut pourtant que 47,5 %. L'écart est constant, d'un facteur 1,18 environ, ce qui correspond à un rendement de pile calculé sur le pouvoir calorifique inférieur et un rendement d'électrolyse calculé sur le supérieur. C'est une interprétation des données, pas une phrase de l'article. Si un examinateur compare vos chiffres à ceux de la littérature, demandez toujours quelle définition est utilisée.

### 3.12 Le réservoir : un gaz réel

À haute pression, l'hydrogène ne suit plus la loi des gaz parfaits, car les molécules occupent elles-mêmes du volume. L'équation d'Abel-Noble corrige cela :

$$p\,(V - n b) = nRT$$

$b = 1{,}55\times10^{-5}$ m³/mol est le « co-volume ». **Exemple :** un réservoir de 5 m³ à 350 bar et 25 °C contient 57 900 mol, soit 117 kg. La loi des gaz parfaits en annoncerait 70 600 mol, 22 % de trop.

### 3.13 La compression

Comprimer l'hydrogène de la pression ambiante à 350 bar coûte de l'énergie. Avec un compresseur à plusieurs étages refroidis et un rendement supposé de 70 %, il faut 24 650 J/mol, soit 3,4 kWh par kilogramme, ou 8,6 % de l'énergie de l'hydrogène.

### 3.14 La thermique de la pile

La température de la pile obéit à un bilan simple :

$$C\,\frac{dT}{dt} = \dot Q + \dot Q_{rég} - \frac{T - T_{amb}}{R_{th}}$$

$C$ est la capacité thermique de la pile, $\dot Q$ sa propre chaleur, $\dot Q_{rég}$ le chauffage ou le refroidissement commandé, et le dernier terme la perte vers l'air ambiant. Un régulateur PI ajuste $\dot Q_{rég}$ pour tenir 80 °C.

Les valeurs de $C$ et $R_{th}$ sont des **estimations**, pas des mesures. L'analyse de sensibilité montre qu'elles n'influencent presque pas les résultats économiques.

### 3.15 Le micro-réseau, en bref

- **Bus continu à 900 V** : c'est le point où tous les équipements échangent de la puissance.
- **Onduleur triphasé** : il convertit le continu en trois tensions alternatives à 60 Hz, décalées de 120°.
- **Repère tournant (transformation de Park)** : en regardant les trois courants depuis un repère qui tourne à 60 Hz, ils deviennent deux valeurs constantes, $i_d$ (puissance active) et $i_q$ (puissance réactive). Des régulateurs PI simples suffisent alors.
- **Boucle à verrouillage de phase** : elle mesure l'angle de la tension du réseau, pour que le repère tournant reste aligné.

Ces notions sont détaillées dans la partie 2, avec le code.

---

## 4. Méthodologie : les choix et leurs raisons

### 4.1 Quel modèle de cellule ?

| Approche | Avantage | Inconvénient |
|---|---|---|
| Courbe empirique ajustée | Très simple | Aucun sens physique : inutilisable si la pression, la température ou le gaz changent |
| **Modèle semi-empirique à paramètres localisés (retenu)** | Physique, rapide, calibrable avec peu de données | Ne décrit pas ce qui se passe à l'intérieur de la cellule |
| Modèle détaillé avec circuits de gaz et transport d'eau | Très fidèle | Impossible à valider sans mesures, trop lent pour simuler une année |

Le critère a été : le modèle le plus détaillé que les données disponibles permettent de calibrer honnêtement.

### 4.2 Pourquoi trois niveaux de fidélité ?

Un transistor commute en microsecondes ; un réservoir d'hydrogène se vide en mois. Aucun modèle unique ne couvre douze ordres de grandeur.

| Niveau | Échelle | Ce qu'il montre | Coût de calcul |
|---|---|---|---|
| Commuté | microseconde | Ondulations, harmoniques | 127 s pour 0,6 s simulée |
| Moyenné | milliseconde | Commande, partage de puissance | 9,7 s pour 0,6 s simulée |
| Quasi-statique | heure | Énergie annuelle, coûts | 4 s pour une année |

Le point important : les trois niveaux partagent **les mêmes équations de cellule et les mêmes paramètres**, et chaque niveau rapide est vérifié contre le niveau lent sur un cas commun.

### 4.3 Quelle gestion d'énergie ?

| Approche | Avantage | Inconvénient |
|---|---|---|
| **Règles (retenu)** | Transparent, explicable, pas besoin de prévision | Pas optimal |
| Optimisation hors ligne | Donne la meilleure solution possible | Suppose de connaître l'avenir |
| Commande prédictive | Bon compromis | Complexe ; toolbox expirée |

Deux variantes de règles sont comparées (batterie d'abord, pile d'abord), ce qui encadre déjà le compromis principal.

### 4.4 Sur quelles données calibrer ?

C'est le choix qui a demandé le plus de recherche.

1. **Tentative 1 : les mesures de la NASA.** Elles sont chiffrées et bien documentées, mais il n'y a que deux points par pile, pour deux paramètres à ajuster. L'ajustement est donc exact par construction, sans rien prouver. De plus, ces piles de 2014 donnent 32 % de rendement aller-retour une fois transposées à une cellule moderne, contre 56 % publiés.
2. **Tentative 2 : numériser une courbe publiée.** Aucun article accessible ne donne de tableau de valeurs, mais un article du laboratoire de Berkeley montre les courbes en figure. Les points ont été relevés par traitement d'image, pas à l'œil, puis vérifiés contre les valeurs écrites dans le texte de l'article.

La deuxième voie donne 24 points pour 6 paramètres : un vrai problème d'ajustement, avec des résidus à examiner.

### 4.5 Combien de paramètres ajuster ?

Plus on ajuste de paramètres, mieux le modèle colle aux points, mais moins il est fiable entre les points. Six jeux de paramètres ont été comparés par **validation croisée** : on retire un point, on ajuste sur les 23 autres, on regarde l'erreur sur le point retiré, et on recommence pour chaque point.

| Paramètres libres | Erreur d'ajustement | Erreur de validation croisée |
|---|---|---|
| 3 | 27,2 mV | 25,6 mV |
| 4 | 14,6 mV | 14,2 mV |
| 5 | 12,6 mV | 12,9 mV |
| **6 (retenu)** | **5,3 mV** | **7,3 mV** |
| 7 | 12,0 mV | 12,3 mV, mais paramètres indiscernables |

Le jeu à 7 paramètres a été écarté parce que ses paramètres ne peuvent pas être distingués les uns des autres (le « conditionnement » du problème est mauvais).

**Une réserve honnête.** L'erreur de 7,3 mV est calculée sur les points intérieurs. Si on retire le dernier point de la courbe à l'air, la prédiction part très loin, car c'est ce seul point qui fixe le courant limite à l'air. Le modèle n'est donc déclaré valide que jusqu'à 1,8 A/cm² à l'air.

### 4.6 Pourquoi générer les modèles Simulink par script ?

Les modèles ne sont pas dessinés à la souris : un script MATLAB crée chaque bloc et chaque connexion. Trois raisons :

- **Reproductibilité** : n'importe qui obtient exactement le même modèle.
- **Traçabilité** : chaque paramètre est visible dans le code, avec son origine.
- **Variantes** : le modèle moyenné et le modèle commuté ne diffèrent que par l'onduleur, ce qui rend leur comparaison rigoureuse.

Le revers est que les schémas produits sont bruts. Ils devront être mis en forme pour la vidéo.

---

Suite : **[Partie 2 — Construction dans MATLAB et Simulink](guide_2_construction.md)**
