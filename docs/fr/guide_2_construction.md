# Guide pédagogique — Partie 2 : la construction dans MATLAB et Simulink

Cette partie parcourt le code. Pour chaque fichier important, elle dit ce qu'il fait, pourquoi il est écrit ainsi, et comment il se relie aux autres. Gardez les fichiers ouverts à côté en lisant.

Parties : [1 — Fondements](guide_1_fondements.md) · **2 — Construction** · [3 — Résultats](guide_3_resultats.md)

---

## 5. Construction MATLAB

### 5.1 L'architecture du projet

```
main.m              lance tout le projet
setupProject.m      prépare le chemin et compile la bibliothèque Simscape
runAllTests.m       lance les 58 tests

simscape/+greenH2/  les 4 composants écrits en Simscape Language
src/+urfc/          la cellule réversible : modèle, paramètres, calibration
src/+h2/            le réservoir et la compression
src/+microgrid/     les lois de commande et la simulation du micro-réseau
src/+solar/         les données météo et le photovoltaïque
src/+longterm/      la simulation annuelle
src/+econ/          les coûts
models/             les scripts qui construisent les modèles Simulink
analysis/           les études qui produisent les figures
validation/         la calibration et les comparaisons
tests/              les tests automatiques
data/               les mesures publiées et les données météo
```

**Les dossiers qui commencent par `+` sont des « paquets » MATLAB.** La fonction `cellModel.m` rangée dans `+urfc` s'appelle `urfc.cellModel`. Cela évite les conflits de noms et montre à quelle partie du projet appartient chaque fonction.

**Le principe d'organisation** : la physique est écrite une seule fois. Par exemple, les équations de la cellule existent dans le composant Simscape et dans `urfc.cellModel`, et un test vérifie que les deux donnent le même résultat. Tout le reste appelle l'un ou l'autre.

### 5.2 `setupProject.m` : préparer l'environnement

Ce fichier fait deux choses :

1. Il ajoute les dossiers au chemin de MATLAB avec `addpath`.
2. Il compile la bibliothèque Simscape avec `sscbuild('greenH2')`, si elle n'existe pas encore.

`sscbuild` lit les fichiers `.ssc` du paquet `+greenH2` et fabrique `greenH2_lib.slx`, une bibliothèque Simulink dont les blocs peuvent être glissés dans un modèle. Ce fichier est généré, donc il n'est pas enregistré dans Git.

### 5.3 Le composant réversible : `ReversibleFuelCell.ssc`

C'est le cœur du projet. Un fichier Simscape Language décrit un composant physique par ses **équations**, pas par une suite d'instructions. Simscape se charge de les résoudre toutes ensemble.

Le fichier est organisé en sections.

**Les ports** (`nodes`, `inputs`, `outputs`) : par où le composant communique.

```
nodes
    p = foundation.electrical.electrical; % +
    n = foundation.electrical.electrical; % -
    H = foundation.thermal.thermal;       % H
end
inputs
    pH2 = {1, 'bar'};
    pO2 = {1, 'bar'};
end
outputs
    nH2 = {0, 'mol/s'};
end
```

- `p` et `n` sont les bornes électriques. Un nœud électrique porte une tension et laisse passer un courant.
- `H` est un port thermique : il porte une température et laisse passer un flux de chaleur.
- `pH2` et `pO2` sont des signaux d'entrée (les pressions), `nH2` un signal de sortie (le débit d'hydrogène).

Chaque grandeur a une **unité**. Simscape vérifie la cohérence des unités dans toutes les équations : c'est un filet de sécurité précieux.

**Les paramètres** (`parameters`) : les valeurs que l'utilisateur peut régler dans la boîte de dialogue du bloc, comme le nombre de cellules ou la surface.

**Les branches** (`branches`) : elles disent par où passent le courant et la chaleur.

```
branches
    i : p.i -> n.i;
    Q : H.Q -> *;
end
```

La première ligne signifie : le courant `i` entre par la borne `p` et sort par la borne `n`. Un courant positif entre donc par le `+`, ce qui correspond à l'électrolyse. C'est ici que se fixe la convention de signe de tout le projet.

**Les grandeurs intermédiaires** (`intermediates`) : ce sont les calculs de la partie 1, écrits presque tels quels. Par exemple l'activation :

```
v_act = R_u*T/(2*alpha*F) * asinh(j/(2*j0));
```

et le choix des paramètres selon le mode :

```
j0    = if ge(j, 0), j0_EC*arrhenius else j0_FC*arrhenius*(pO2_lim/p_std)^gamma_O2 end;
alpha = if ge(j, 0), alpha_EC else alpha_FC end;
```

`ge(j, 0)` veut dire « j supérieur ou égal à 0 ». En électrolyse on prend les paramètres `_EC`, en mode pile les paramètres `_FC`. Comme la surtension d'activation vaut zéro à `j = 0`, ce changement ne crée pas de saut de tension.

**Les équations** (`equations`) : les trois relations que Simscape doit satisfaire.

```
v == N_cell * v_cell;
nH2 == N_cell * A_cell * (j - j_cross) / (2*F);
Q == -power_heat;
```

Le signe `==` n'est pas une affectation : c'est une **égalité à respecter**. Simscape trouve les valeurs qui satisfont toutes les égalités de tous les composants en même temps.

**Les garde-fous** (`assert`) : le composant refuse des paramètres absurdes et s'arrête si la température devient négative. Ce dernier garde-fou a été ajouté après une erreur réelle : un capteur branché à l'envers donnait −353 K et le modèle tournait quand même.

### 5.4 Le même modèle en MATLAB : `urfc.cellModel`

Cette fonction contient exactement les mêmes équations, écrites en MATLAB ordinaire. Elle sert à trois choses que Simscape ne fait pas bien : calibrer, simuler une année très vite, et servir de référence pour les tests.

Elle est **vectorisée** : on peut lui donner un vecteur de 1 000 densités de courant et elle renvoie 1 000 tensions d'un coup. Le choix du mode se fait par un masque logique :

```matlab
isEC = j >= 0;
alpha = isEC*par.alphaEC + ~isEC*par.alphaFC;
```

`isEC` vaut 1 là où le courant est positif, 0 ailleurs. La ligne suivante choisit donc `alphaEC` ou `alphaFC` élément par élément, sans boucle.

Le bloc `arguments` en tête de fonction vérifie les entrées :

```matlab
arguments
    j   double
    T   double {mustBePositive}
    ...
end
```

Si on appelle la fonction avec une température négative, MATLAB s'arrête avec un message clair.

### 5.5 Les paramètres : `defaultParameters`, `lbnlParameters`, `applyToBlock`

- `urfc.defaultParameters` donne un jeu de base, aligné sur les exemples MathWorks pour pouvoir s'y comparer.
- `urfc.lbnlParameters` donne le jeu calibré sur la cellule publiée, avec son domaine de validité. C'est celui qui sert partout ensuite.
- `urfc.applyToBlock` écrit une structure de paramètres dans un bloc Simulink, avec `set_param`. C'est le pont entre MATLAB et Simulink : il garantit que le bloc et la fonction MATLAB utilisent bien les mêmes valeurs.

### 5.6 La calibration : `urfc.calibrate`

Calibrer, c'est chercher les paramètres qui rendent le modèle le plus proche possible des mesures. On minimise la somme des carrés des écarts de tension. MATLAB fait cela avec `lsqnonlin` (Optimization Toolbox).

Trois détails méritent d'être compris.

**Le logarithme.** Les courants d'échange varient sur plusieurs ordres de grandeur ($10^{-6}$ à $10^{-3}$). On ajuste donc leur logarithme, pas leur valeur, sinon l'algorithme avance mal :

```matlab
toX = @(p) ifelse(isLog, log10(p), p);
fromX = @(x) ifelse(isLog, 10.^x, x);
```

**Les degrés de liberté.** C'est le nombre de points moins le nombre de paramètres. S'il vaut zéro, l'ajustement est exact et ne prouve rien. La fonction le renvoie explicitement.

**Le conditionnement.** La fonction calcule le conditionnement de la matrice jacobienne. Un nombre très grand signifie que deux paramètres ont presque le même effet sur les courbes et ne peuvent pas être séparés. C'est ce critère qui a écarté le jeu à 7 paramètres.

### 5.7 La numérisation : `digitizePengFigure2a`

Ce script lit une figure publiée et en extrait les points, sans intervention manuelle. Les étapes :

1. **Trouver les axes.** Les lignes des axes sont les plus longues rangées de pixels sombres. Les graduations sont de petits segments sombres juste à côté.
2. **Étalonner.** L'écart entre deux graduations vaut 0,2 V : on en déduit la tension par pixel.
3. **Séparer les courbes par couleur.** Les marqueurs bleus sont la charge, les verts la décharge à l'oxygène, les rouges la décharge à l'air.
4. **Isoler les marqueurs.** Une opération appelée « ouverture morphologique » (`imopen`) efface les traits fins qui relient les marqueurs et ne garde que les marqueurs eux-mêmes. Leur centre donne le point.

Deux vérifications montrent que la numérisation est juste : les points tombent à 2 mA/cm² près sur la grille de mesure (multiples de 200 mA/cm²), et les rendements lus sur la figure retrouvent ceux qui sont écrits dans le texte de l'article (56,2 % lus contre 56,4 % écrits).

La figure elle-même n'est pas dans le dépôt, pour des raisons de droit d'auteur. Seuls les nombres extraits y sont, dans un fichier CSV.

### 5.8 Le réservoir : `HydrogenTank.ssc`

Ce composant a un **état** : la quantité d'hydrogène stockée, `n`. Son équation différentielle est la plus simple possible :

```
der(n) == nH2;
p == n*R_u*T_tank/(V_tank - n*b_H2);
```

`der(n)` est la dérivée de `n` par rapport au temps. La première ligne dit donc : la quantité stockée varie au rythme du débit entrant. La seconde est l'équation d'Abel-Noble.

La valeur de départ est fixée par une équation initiale :

```
equations (Initial = true)
    n == n_init;
end
```

Les fonctions `h2.tankPressure` et `h2.tankMoles` sont les équivalents MATLAB, inverses l'une de l'autre.

### 5.9 Les convertisseurs moyennés

Un convertisseur réel découpe la tension des milliers de fois par seconde. Un modèle **moyenné** ignore ce découpage et ne garde qu'une chose : la puissance se conserve, au rendement près.

`DcDcCurrentControlled.ssc` sert à la batterie et à la pile. Il impose un courant côté appareil et calcule ce qui est prélevé sur le bus :

```
i1 == iRef;
power_bus = if ge(power_device, 0), power_device/eta else power_device*eta end;
i2 == power_bus/v2_lim;
```

Si l'appareil absorbe de la puissance, le bus doit en fournir un peu plus (division par le rendement). S'il en fournit, le bus en reçoit un peu moins (multiplication). `DcDcVoltageControlled.ssc` fait la même chose pour le photovoltaïque, mais en imposant la tension.

### 5.10 Les lois de commande

Les trois lois sont écrites comme des fonctions MATLAB simples, avec leur état passé en argument. Cela permet de les tester sans Simulink.

**`microgrid.mpptStep` — chercher le point de puissance maximale.** Un panneau solaire fournit sa puissance maximale à une tension précise, qui change avec l'ensoleillement. L'algorithme « perturber et observer » est très simple : on déplace un peu la tension ; si la puissance a augmenté, on continue dans le même sens ; sinon, on repart dans l'autre.

```matlab
if power < state(2)
    state(3) = -state(3);      % la puissance a baissé : on inverse le sens
end
vRef = state(1) + state(3)*p.vMpptStep;
```

**`microgrid.inverterControlStep` — piloter l'onduleur.** C'est la loi la plus technique. Elle se lit en quatre étapes.

1. *Transformation de Park.* Les trois tensions et les trois courants sont projetés sur un repère qui tourne avec le réseau. Ils deviennent des valeurs constantes : `vd`, `vq`, `id`, `iq`.
2. *Boucle à verrouillage de phase.* Si le repère est bien aligné, `vq` vaut zéro. Un régulateur PI corrige la vitesse de rotation jusqu'à annuler `vq`.
3. *Boucle de tension.* Si la tension du bus dépasse 900 V, c'est qu'il y a trop d'énergie : on demande à l'onduleur d'en envoyer davantage au réseau, en augmentant la consigne `idRef`.
4. *Boucles de courant.* Deux régulateurs PI font suivre `id` et `iq` à leurs consignes, puis la transformation inverse donne les trois signaux de modulation.

Les gains ne sont pas choisis au hasard. Pour la boucle de courant, on veut une bande passante de 300 Hz, et on choisit les gains pour compenser exactement la dynamique du filtre : `kp = L × ωc` et `ki = R × ωc`, soit 3,77 et 94,2.

**`microgrid.emsStep` — partager la puissance.** Quatre règles :

1. Calculer l'excédent ou le déficit sur le bus : production solaire moins consommation.
2. La pile le suit : électrolyse s'il y a un excédent, mode pile s'il y a un déficit. Elle respecte ses limites de courant, une zone morte de 2 kW, l'état du réservoir, et une vitesse de variation maximale de 300 A/s.
3. La batterie prend le reste.
4. Ce que ni l'une ni l'autre ne peut couvrir va au réseau, automatiquement, par la boucle de tension de l'onduleur.

**`microgrid.controlParameters`** regroupe tous les réglages. Une particularité : cette fonction doit pouvoir être traduite en code C par Simulink. Or on ne peut pas ajouter de champ à une structure après l'avoir lue. Les valeurs sont donc calculées dans des variables locales, puis la structure est créée d'un seul coup. C'est une erreur qui a réellement bloqué le modèle avant d'être comprise.

### 5.11 Construire les modèles par script

`models/buildMicrogridAverage.m` crée le modèle du micro-réseau. Trois commandes font presque tout :

```matlab
add_block('ee_lib/Sources/Battery', blk('Battery'));           % ajouter un bloc
set_param(blk('Battery'), 'Vnom', num(cfg.battery.vNominal));  % régler un paramètre
simscape.addConnection(blk('Battery'), 'p', blk('Battery Converter'), 'p1');  % relier deux ports
```

Les lois de commande sont placées dans des blocs « MATLAB Function », dont le script écrit le contenu. Chaque bloc garde son état d'un pas à l'autre grâce à une variable `persistent` :

```matlab
function [m, dbg] = inverterController(vabc, iabc, vdc)
persistent state
p = microgrid.controlParameters();
if isempty(state)
    state = zeros(5, 1);
end
[m, state, dbg] = microgrid.inverterControlStep(vabc(:), iabc(:), vdc, state, p);
end
```

Chaque sortie de commande passe par un **retard d'un pas** (`Unit Delay`). Cela a deux raisons : c'est réaliste (un calculateur met du temps à calculer), et cela évite une boucle algébrique entre la commande et le circuit.

**L'option commutée.** Si `cfg.inverterFidelity` vaut `"switching"`, le script remplace l'onduleur moyenné par un onduleur à six interrupteurs, et ajoute la modulation de largeur d'impulsion : chaque signal de modulation est comparé à un triangle à 10 kHz. Quand le signal dépasse le triangle, l'interrupteur du haut conduit ; sinon, celui du bas.

### 5.12 Les modèles enregistrés : `buildPresentationModels`

Les scripts de construction produisent des modèles « à plat » : 80 blocs côte à côte pour le micro-réseau. C'est pratique pour le code (les analyses retrouvent chaque bloc par son nom dans les résultats), mais illisible à l'écran.

`models/buildPresentationModels.m` produit donc les deux modèles enregistrés dans `models/`, organisés en sous-systèmes nommés : photovoltaïque, batterie, pile réversible et réservoir, bus continu, onduleur avec réseau et charge. Les ports portent des noms parlants (`DC+`, `DC-`, `vdc`, `iUrfcRef`…), et un scénario par défaut est rangé dans l'espace de travail du modèle, pour qu'il tourne dès son ouverture.

La méthode mérite d'être connue, car la plus simple a échoué :

1. **Tentative avec `Simulink.BlockDiagram.createSubsystem`.** C'est la fonction prévue pour regrouper des blocs. Elle a d'abord fait planter MATLAB, puis produit un modèle faux : même blocs, mêmes réglages, mais la puissance de l'onduleur passait de 20,0 à 10,8 kW. Les connexions physiques avaient été mal reconstruites à la frontière des sous-systèmes.
2. **Méthode retenue.** Le script lit toutes les connexions du modèle à plat (avec `PortConnectivity`, qui donne pour chaque port physique les ports auxquels il est relié), vide le schéma de ses lignes, déplace les blocs dans des sous-systèmes vides, puis recâble chaque connexion. Une connexion qui reste dans un sous-système est refaite à l'intérieur ; une connexion qui traverse une frontière passe par un port nommé.
3. **Vérification.** Le test `tPresentationModels` simule chaque modèle enregistré et son équivalent à plat avec les mêmes entrées, et exige le même résultat à 10⁻⁶ près.

La leçon : un modèle qui « a l'air juste » n'est pas forcément juste. Sans la comparaison par simulation, le modèle faux aurait été enregistré et montré dans la vidéo.

### 5.13 Le modèle annuel : `longterm.simulate`

Sur une année, on ne peut pas simuler chaque milliseconde. On raisonne heure par heure, en supposant que tout est à l'équilibre pendant l'heure.

La pile est d'abord **tabulée** par `longterm.urfcMap` : pour 400 valeurs de densité de courant, on calcule avec `urfc.cellModel` la puissance, le débit d'hydrogène et la chaleur. Pendant la simulation, on lit ces tables par interpolation.

Ensuite, pour chacune des 8 760 heures :

1. Calculer la production solaire et la consommation, donc l'excédent ou le déficit.
2. Servir d'abord le soutirage d'hydrogène, s'il y en a un.
3. Répartir entre batterie et pile, selon la stratégie.
4. Envoyer le reste au réseau.
5. Mettre à jour le réservoir, la batterie et la température de la pile.

Un point délicat : on connaît la puissance disponible, mais les tables sont rangées par densité de courant. Il faut donc **inverser** la table : trouver le courant qui consomme exactement la puissance disponible, en comptant le convertisseur, le compresseur et le chauffage. C'est le rôle de la petite fonction `monotonicInverse`.

`longterm.simulateCyclic` relance la simulation en repartant du niveau final du réservoir, jusqu'à ce que le niveau de fin d'année égale celui du début. Sans cela, un réservoir qui se vide sur l'année fausserait les résultats en « offrant » de l'hydrogène gratuit.

### 5.14 Le solaire : `+solar`

- `readNasaPower` lit le fichier météo et vérifie qu'il ne manque aucune valeur.
- `sunPosition` calcule où se trouve le soleil à chaque heure (hauteur et direction), à partir de la date, de l'heure et des coordonnées du site.
- `planeOfArray` calcule l'éclairement reçu par un panneau incliné : la part directe (qui dépend de l'angle entre le soleil et le panneau), la part diffuse du ciel et la part réfléchie par le sol.
- `pvPower` en déduit la puissance, en tenant compte du fait qu'un panneau chaud produit moins (−0,4 % par degré).

### 5.15 L’économie : `+econ`

- `costData` rassemble toutes les données de coût, **chacune avec sa source** écrite en commentaire, et la liste des hypothèses sans source.
- `capitalRecoveryFactor` transforme un investissement en annuité. Pour 8 % sur 25 ans, le facteur vaut 0,0937 : un investissement de 100 000 $ équivaut à 9 370 $ par an.
- `evaluate` additionne les annuités, l'entretien et la facture d'électricité, puis divise par l'énergie consommée pour obtenir un coût en $/kWh.

Un détail important : la durée de vie de la pile n'est pas fixée. Elle est calculée à partir des heures de fonctionnement simulées. Une pile garantie 40 000 heures qui tourne 5 700 heures par an dure 7 ans.

### 5.16 Les tests

Les 58 tests sont rangés en six classes. Un test est une petite fonction qui vérifie une affirmation précise :

```matlab
function faradayLaw(testCase)
    p = testCase.Par; p.psiH2 = 0;
    out = urfc.cellModel(1, 353.15, 1, 1, p);
    testCase.verifyEqual(out.nH2, 1/(2*96485.33212), 'RelTol', 1e-12);
end
```

Celui-ci vérifie la loi de Faraday : à 1 A/cm² et sans fuite, le débit doit valoir exactement $1/(2F)$.

Les tests couvrent cinq familles : la physique (lois, limites, signes), l'accord entre Simscape et MATLAB, les bilans de matière et d'énergie, la logique des lois de commande, et les calculs de coût. Ils se lancent avec `runAllTests`.

---

## 6. Simulation

### 6.1 Comment lancer

```matlab
main            % démonstration rapide, environ 3 à 5 minutes
main("full")    % ajoute les études longues
runAllTests     % les 58 tests, environ 7 minutes
```

Avant toute chose, MATLAB doit être ouvert dans le dossier du projet. Si vous utilisez l'agent, tapez d'abord `shareMATLABSession()` dans MATLAB ; c'est à refaire après chaque redémarrage.

### 6.2 Les réglages du solveur

| Modèle | Solveur | Pas maximal | Raison |
|---|---|---|---|
| Stockage (pile + thermique + réservoir) | `ode23t` | 5 s | Dynamiques lentes (thermique) |
| Micro-réseau moyenné | `ode23t` | 100 µs | Il faut bien décrire le 60 Hz |
| Micro-réseau commuté | `ode23t` | 2,5 µs | 40 pas par période de découpage |
| Annuel | aucun (calcul heure par heure) | 1 h | Régime établi |

`ode23t` est un solveur adapté aux systèmes « raides », où des phénomènes très rapides et très lents coexistent, ce qui est typique des circuits électriques.

### 6.3 Les scénarios

- **Cycle de stockage** : 20 minutes de chauffe, 2 heures d'électrolyse à 1 A/cm², 10 minutes d'arrêt, 3 heures en mode pile à 0,5 A/cm².
- **Micro-réseau** : 5 secondes. L'ensoleillement chute de 800 à 200 W/m² à 1,5 s (un nuage), puis la charge passe de 20 à 35 kW à 3,5 s.
- **Année** : 2023, à Daggett (Californie) et Houston (Texas), avec une charge moyenne de 20 kW.

### 6.4 Les difficultés rencontrées, et ce qu'elles apprennent

Ces erreurs sont utiles à connaître : un examinateur peut demander ce qui a été difficile.

| Problème | Cause | Leçon |
|---|---|---|
| Écart de 113 mV avec l'exemple MathWorks | Utilisation des valeurs par défaut du fichier, et non de celles réellement réglées dans le modèle | Toujours lire les paramètres dans le modèle, pas dans le code source |
| Température de −353 K sans erreur | Source de température branchée à l'envers | Mettre des garde-fous (`assert`) dans les composants |
| Le micro-réseau refuse de démarrer (« système singulier ») | L'inductance interne du réseau, en série avec le filtre, avec la charge au milieu | Deux inductances en série avec une source de courant entre elles sont un piège classique ; le réseau est donc idéal |
| Nœuds électriques non reliés | Plusieurs blocs reliés par programme à la même masse | Une référence électrique par sous-ensemble |
| Le bloc de commande ne compile pas | Ajout d'un champ à une structure déjà lue | Construire la structure d'un seul coup |
| Résultats tronqués sur une longue simulation | Le journal Simscape ne garde que les 10 000 derniers pas par défaut | Lever cette limite ; un bilan qui « ferme » sur un extrait ne prouve rien sur l'ensemble |
| Plantage de MATLAB, puis modèle regroupé en sous-systèmes faux (20,0 kW devenus 10,8 kW) | `createSubsystem` reconstruit mal certaines connexions physiques | Toujours comparer par simulation un modèle restructuré à l'original |
| Calibration peu représentative | Mesures de 2014, deux points seulement | Chercher de meilleures données plutôt que forcer le modèle |

Le sixième point a obligé à corriger un chiffre déjà annoncé : le résidu du bilan de puissance du micro-réseau valait 677 J sur les 5 secondes complètes, et non 47,6 J comme calculé d'abord sur la seule fin de la simulation.

---

Suite : **[Partie 3 — Résultats, validation, limites et conclusion](guide_3_resultats.md)**
