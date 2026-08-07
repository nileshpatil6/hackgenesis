import 'dart:math';

import 'package:flutter/foundation.dart';

/// A single multiple-choice question shown while an experiment is running.
///
/// Entirely local: the waiting screen must never add load to the API it is
/// waiting on.
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.category,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.fact,
  });

  /// A [ComponentCategory] id, or `general` for questions that fit any build.
  final String category;
  final String question;
  final List<String> options;
  final int correctIndex;

  /// One-line takeaway revealed once the player answers.
  final String fact;

  String get correctAnswer => options[correctIndex];
}

/// Questions that fit any experiment, used to top up a short domain set.
const String kGeneralCategory = 'general';

/// The full local question bank, grouped by the domain it belongs to.
const List<QuizQuestion> kQuizQuestions = <QuizQuestion>[
  // ------------------------------------------------------------ electronics
  QuizQuestion(
    category: 'electronics',
    question: 'What does a resistor actually do in a circuit?',
    options: <String>[
      'Limits how much current can flow',
      'Stores energy in a magnetic field',
      'Converts AC into DC',
      'Increases the supply voltage',
    ],
    correctIndex: 0,
    fact: 'Resistance turns electrical energy into heat, capping the current.',
  ),
  QuizQuestion(
    category: 'electronics',
    question: 'Why does an LED usually need a resistor in series with it?',
    options: <String>[
      'To make it glow brighter',
      'To stop it drawing enough current to destroy itself',
      'To convert the current to AC',
      'To slow the light down',
    ],
    correctIndex: 1,
    fact: 'An LED barely resists current on its own, so it needs help.',
  ),
  QuizQuestion(
    category: 'electronics',
    question: 'Ohm\'s law relates voltage, current and resistance as:',
    options: <String>['V = I / R', 'V = I × R', 'V = R / I', 'V = I + R'],
    correctIndex: 1,
    fact: 'V = I × R — the one equation almost every circuit comes back to.',
  ),
  QuizQuestion(
    category: 'electronics',
    question: 'In a series circuit, the current through each component is:',
    options: <String>[
      'The same everywhere',
      'Split evenly between them',
      'Highest at the last component',
      'Zero unless it branches',
    ],
    correctIndex: 0,
    fact: 'One path means one current — it is the voltage that divides up.',
  ),
  QuizQuestion(
    category: 'electronics',
    question: 'What is a capacitor best at?',
    options: <String>[
      'Storing charge and releasing it quickly',
      'Permanently blocking all current',
      'Amplifying a weak signal',
      'Measuring temperature',
    ],
    correctIndex: 0,
    fact: 'Capacitors buffer charge, which smooths out sudden voltage dips.',
  ),

  // -------------------------------------------------------------- chemicals
  QuizQuestion(
    category: 'chemicals',
    question: 'On the pH scale, a value below 7 means the solution is:',
    options: <String>['Acidic', 'Basic', 'Neutral', 'Saturated'],
    correctIndex: 0,
    fact: 'Lower pH means more free hydrogen ions — that is acidity.',
  ),
  QuizQuestion(
    category: 'chemicals',
    question: 'What do you get when an acid neutralises a base?',
    options: <String>[
      'A salt and water',
      'Pure hydrogen gas',
      'Nothing — they cancel out',
      'An explosion, always',
    ],
    correctIndex: 0,
    fact: 'Acid + base gives a salt plus water. Reliable, and often warm.',
  ),
  QuizQuestion(
    category: 'chemicals',
    question: 'A catalyst changes a reaction by:',
    options: <String>[
      'Speeding it up without being consumed',
      'Adding extra product',
      'Raising the temperature permanently',
      'Making it irreversible',
    ],
    correctIndex: 0,
    fact: 'Catalysts lower the activation energy and walk away unchanged.',
  ),
  QuizQuestion(
    category: 'chemicals',
    question: 'An exothermic reaction is one that:',
    options: <String>[
      'Releases heat to its surroundings',
      'Absorbs heat from its surroundings',
      'Happens only in a vacuum',
      'Cannot be reversed',
    ],
    correctIndex: 0,
    fact: 'Exothermic reactions warm the beaker. Endothermic ones cool it.',
  ),

  // ---------------------------------------------------------------- physics
  QuizQuestion(
    category: 'physics',
    question: 'What decides how fast a simple pendulum swings?',
    options: <String>[
      'Mostly its length',
      'Mostly the mass of the bob',
      'The colour of the string',
      'How hard you push it',
    ],
    correctIndex: 0,
    fact: 'Period depends on length and gravity — not on the mass.',
  ),
  QuizQuestion(
    category: 'physics',
    question: 'Newton\'s second law is usually written as:',
    options: <String>['F = m × a', 'F = m / a', 'F = a / m', 'F = m + a'],
    correctIndex: 0,
    fact: 'Force equals mass times acceleration.',
  ),
  QuizQuestion(
    category: 'physics',
    question: 'Energy in a closed system is:',
    options: <String>[
      'Conserved — it changes form but never vanishes',
      'Created steadily over time',
      'Destroyed by friction',
      'Only conserved in a vacuum',
    ],
    correctIndex: 0,
    fact: 'Friction does not destroy energy, it converts it into heat.',
  ),
  QuizQuestion(
    category: 'physics',
    question: 'Two objects of different mass fall in a vacuum. They land:',
    options: <String>[
      'At the same time',
      'Heavier one first',
      'Lighter one first',
      'Neither falls in a vacuum',
    ],
    correctIndex: 0,
    fact: 'Without air resistance, gravity accelerates everything equally.',
  ),

  // ---------------------------------------------------------------- biology
  QuizQuestion(
    category: 'biology',
    question: 'Which part of the cell is called the powerhouse?',
    options: <String>[
      'The mitochondrion',
      'The nucleus',
      'The ribosome',
      'The cell wall',
    ],
    correctIndex: 0,
    fact: 'Mitochondria turn nutrients into ATP, the cell\'s usable energy.',
  ),
  QuizQuestion(
    category: 'biology',
    question: 'Photosynthesis converts light energy mainly into:',
    options: <String>[
      'Chemical energy stored in sugars',
      'Electrical energy',
      'Sound energy',
      'Nuclear energy',
    ],
    correctIndex: 0,
    fact: 'Plants bank sunlight as glucose, releasing oxygen as a by-product.',
  ),
  QuizQuestion(
    category: 'biology',
    question: 'DNA carries information using how many base letters?',
    options: <String>['Four', 'Two', 'Twenty', 'Sixty-four'],
    correctIndex: 0,
    fact: 'A, T, C and G — four letters is enough to encode a whole organism.',
  ),

  // ----------------------------------------------------------------- coding
  QuizQuestion(
    category: 'coding',
    question: 'What does a conditional (if) block do in a flow?',
    options: <String>[
      'Chooses a path based on whether something is true',
      'Repeats a step forever',
      'Stores a value for later',
      'Ends the program',
    ],
    correctIndex: 0,
    fact: 'Conditionals are where a program stops being a straight line.',
  ),
  QuizQuestion(
    category: 'coding',
    question: 'A loop that never meets its exit condition causes:',
    options: <String>[
      'An infinite loop',
      'A syntax error',
      'A faster program',
      'Automatic garbage collection',
    ],
    correctIndex: 0,
    fact: 'Every loop needs a condition that eventually becomes false.',
  ),
  QuizQuestion(
    category: 'coding',
    question: 'What is a variable, at its simplest?',
    options: <String>[
      'A named box that holds a value',
      'A kind of loop',
      'A hardware component',
      'A type of error',
    ],
    correctIndex: 0,
    fact: 'Name it well and half the program explains itself.',
  ),

  // ------------------------------------------------------------ mathematics
  QuizQuestion(
    category: 'mathematics',
    question: 'What is the mean of 2, 4, 6 and 8?',
    options: <String>['5', '4', '6', '20'],
    correctIndex: 0,
    fact: 'The four values total 20, and 20 divided by 4 is 5.',
  ),
  QuizQuestion(
    category: 'mathematics',
    question: 'In a right triangle, Pythagoras\' theorem states:',
    options: <String>['a² + b² = c²', 'a + b = c', 'a × b = c', 'a² − b² = c²'],
    correctIndex: 0,
    fact: 'The square on the hypotenuse equals the sum of the other two.',
  ),
  QuizQuestion(
    category: 'mathematics',
    question: 'A function must give, for each input:',
    options: <String>[
      'Exactly one output',
      'At least two outputs',
      'A random output',
      'No output',
    ],
    correctIndex: 0,
    fact: 'One input, one output — that is what makes it a function.',
  ),

  // --------------------------------------------------------- thermodynamics
  QuizQuestion(
    category: 'thermodynamics',
    question: 'Heat always flows naturally from:',
    options: <String>[
      'Hotter to colder',
      'Colder to hotter',
      'Denser to lighter',
      'Left to right',
    ],
    correctIndex: 0,
    fact: 'Reversing that flow costs energy — that is what a fridge is for.',
  ),
  QuizQuestion(
    category: 'thermodynamics',
    question: 'At what temperature does water boil at sea level?',
    options: <String>['100°C', '90°C', '120°C', '75°C'],
    correctIndex: 0,
    fact: 'Boiling point drops with altitude as air pressure falls.',
  ),
  QuizQuestion(
    category: 'thermodynamics',
    question: 'Entropy in an isolated system tends to:',
    options: <String>[
      'Increase over time',
      'Decrease over time',
      'Stay exactly constant',
      'Oscillate',
    ],
    correctIndex: 0,
    fact: 'The second law: disorder wins unless you spend energy fighting it.',
  ),

  // ----------------------------------------------------------------- optics
  QuizQuestion(
    category: 'optics',
    question: 'What happens when light passes from air into glass?',
    options: <String>[
      'It bends and slows down',
      'It speeds up',
      'It stops entirely',
      'It turns into heat',
    ],
    correctIndex: 0,
    fact: 'That bending is refraction, and it is how lenses focus light.',
  ),
  QuizQuestion(
    category: 'optics',
    question: 'A convex lens is typically used to:',
    options: <String>[
      'Converge light to a focal point',
      'Spread light apart',
      'Block all light',
      'Change light into sound',
    ],
    correctIndex: 0,
    fact: 'Convex converges, concave diverges.',
  ),
  QuizQuestion(
    category: 'optics',
    question: 'White light splits into colours through a prism because:',
    options: <String>[
      'Each wavelength bends by a different amount',
      'The prism adds colour',
      'Glass is naturally rainbow-coloured',
      'The light heats up',
    ],
    correctIndex: 0,
    fact: 'Dispersion: blue bends more than red, so the colours fan out.',
  ),

  // ---------------------------------------------------------------- quantum
  QuizQuestion(
    category: 'quantum',
    question:
        'Heisenberg\'s uncertainty principle says you cannot precisely '
        'know both:',
    options: <String>[
      'Position and momentum',
      'Mass and charge',
      'Colour and shape',
      'Time and temperature',
    ],
    correctIndex: 0,
    fact: 'Pin down where it is and you lose track of how fast it is going.',
  ),
  QuizQuestion(
    category: 'quantum',
    question: 'A qubit differs from a classical bit because it can be:',
    options: <String>[
      'In a superposition of 0 and 1',
      'Only ever 0',
      'Larger than a byte',
      'Read without any error',
    ],
    correctIndex: 0,
    fact: 'Superposition is what gives quantum computers their leverage.',
  ),

  // -------------------------------------------------------------- mechanics
  QuizQuestion(
    category: 'mechanics',
    question: 'A lever makes work easier by trading:',
    options: <String>[
      'Distance for force',
      'Mass for energy',
      'Heat for light',
      'Time for temperature',
    ],
    correctIndex: 0,
    fact: 'Move the effort further and you need less of it.',
  ),
  QuizQuestion(
    category: 'mechanics',
    question: 'Friction between two sliding surfaces mostly produces:',
    options: <String>['Heat', 'Light', 'Sound only', 'Electricity'],
    correctIndex: 0,
    fact: 'Rub your hands together — that warmth is lost kinetic energy.',
  ),

  // -------------------------------------------------------------- astronomy
  QuizQuestion(
    category: 'astronomy',
    question: 'What keeps planets in orbit around a star?',
    options: <String>['Gravity', 'Magnetism', 'Air pressure', 'The solar wind'],
    correctIndex: 0,
    fact: 'An orbit is really just falling sideways fast enough to miss.',
  ),
  QuizQuestion(
    category: 'astronomy',
    question: 'A light-year is a unit of:',
    options: <String>['Distance', 'Time', 'Brightness', 'Mass'],
    correctIndex: 0,
    fact: 'It is how far light travels in a year — about 9.5 trillion km.',
  ),

  // ---------------------------------------------------------------- geology
  QuizQuestion(
    category: 'geology',
    question: 'Which rock type forms from cooled molten magma?',
    options: <String>['Igneous', 'Sedimentary', 'Metamorphic', 'Organic'],
    correctIndex: 0,
    fact: 'Igneous means "from fire" — granite and basalt both qualify.',
  ),
  QuizQuestion(
    category: 'geology',
    question: 'Earthquakes are mostly caused by:',
    options: <String>[
      'Tectonic plates slipping past each other',
      'Heavy rainfall',
      'The moon\'s light',
      'Ocean currents',
    ],
    correctIndex: 0,
    fact: 'Stress builds along a fault until the rock suddenly gives way.',
  ),

  // ------------------------------------------------------------------ music
  QuizQuestion(
    category: 'music',
    question: 'Doubling a sound wave\'s frequency raises the pitch by:',
    options: <String>[
      'One octave',
      'One semitone',
      'A fifth',
      'It does not change',
    ],
    correctIndex: 0,
    fact: 'Every octave up is exactly double the frequency.',
  ),
  QuizQuestion(
    category: 'music',
    question: 'A wave\'s amplitude corresponds to its:',
    options: <String>['Loudness', 'Pitch', 'Timbre', 'Tempo'],
    correctIndex: 0,
    fact: 'Bigger wave, louder sound. Faster wave, higher note.',
  ),

  // --------------------------------------------------------------- robotics
  QuizQuestion(
    category: 'robotics',
    question: 'What does a sensor do in a robot?',
    options: <String>[
      'Turns something physical into a signal it can read',
      'Provides the motive power',
      'Stores the program',
      'Holds the frame together',
    ],
    correctIndex: 0,
    fact: 'No sensing, no feedback — and no reacting to the real world.',
  ),
  QuizQuestion(
    category: 'robotics',
    question: 'In a feedback control loop, the controller compares:',
    options: <String>[
      'The measured value against the target',
      'Two different motors',
      'Voltage against current',
      'Input against the power supply',
    ],
    correctIndex: 0,
    fact: 'The gap between wanted and actual is what drives the correction.',
  ),

  // ------------------------------------------------------------------ ai_ml
  QuizQuestion(
    category: 'ai_ml',
    question: 'What is a neural network\'s training data used for?',
    options: <String>[
      'Adjusting the weights so predictions improve',
      'Storing the final answers',
      'Cooling the processor',
      'Drawing the interface',
    ],
    correctIndex: 0,
    fact: 'Training is just nudging weights until the error stops shrinking.',
  ),
  QuizQuestion(
    category: 'ai_ml',
    question:
        'A model that memorises its training data but fails on new data '
        'is said to be:',
    options: <String>[
      'Overfitting',
      'Underfitting',
      'Converging',
      'Normalising',
    ],
    correctIndex: 0,
    fact: 'Overfitting is learning the noise instead of the pattern.',
  ),

  // ---------------------------------------------------------------- general
  QuizQuestion(
    category: kGeneralCategory,
    question: 'In an experiment, the variable you deliberately change is the:',
    options: <String>[
      'Independent variable',
      'Dependent variable',
      'Control variable',
      'Constant',
    ],
    correctIndex: 0,
    fact: 'You change the independent one and watch the dependent one respond.',
  ),
  QuizQuestion(
    category: kGeneralCategory,
    question: 'Why does a good experiment need a control group?',
    options: <String>[
      'To show what happens when nothing is changed',
      'To double the results',
      'To speed the experiment up',
      'To make the maths easier',
    ],
    correctIndex: 0,
    fact: 'Without a baseline you cannot tell an effect from a coincidence.',
  ),
  QuizQuestion(
    category: kGeneralCategory,
    question: 'A hypothesis is best described as:',
    options: <String>[
      'A testable prediction',
      'A proven fact',
      'A final conclusion',
      'A measurement',
    ],
    correctIndex: 0,
    fact: 'If there is no way to prove it wrong, it is not a hypothesis.',
  ),
  QuizQuestion(
    category: kGeneralCategory,
    question: 'Repeating an experiment several times mainly helps you:',
    options: <String>[
      'Spot results that were just chance',
      'Use up spare components',
      'Change the outcome',
      'Avoid writing it up',
    ],
    correctIndex: 0,
    fact: 'One result is an anecdote; a repeated result is evidence.',
  ),
  QuizQuestion(
    category: kGeneralCategory,
    question: 'In science, what makes a measurement precise?',
    options: <String>[
      'Repeated readings agree closely with each other',
      'It is close to the true value',
      'It uses the largest number',
      'It was taken quickly',
    ],
    correctIndex: 0,
    fact: 'Precise means consistent; accurate means correct. Not the same.',
  ),
];

/// Builds a quiz tuned to the domains present in the current experiment.
///
/// Questions from [categories] come first so the quiz feels like it is about
/// what the player actually built, topped up with general science questions
/// when a build only touches one or two fields. Order is shuffled per call so
/// repeat runs do not replay the same sequence.
List<QuizQuestion> quizForCategories(
  Iterable<String> categories, {
  int count = 12,
  int? seed,
}) {
  final wanted = categories.toSet();
  final random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  final matching =
      kQuizQuestions.where((q) => wanted.contains(q.category)).toList()
        ..shuffle(random);
  final general =
      kQuizQuestions.where((q) => q.category == kGeneralCategory).toList()
        ..shuffle(random);
  final rest =
      kQuizQuestions
          .where(
            (q) =>
                !wanted.contains(q.category) && q.category != kGeneralCategory,
          )
          .toList()
        ..shuffle(random);

  // Domain questions first, then general, then anything else as filler so the
  // player never runs out while a slow request is still in flight.
  return <QuizQuestion>[...matching, ...general, ...rest].take(count).toList();
}
