const { onCall } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const { OpenAI } = require("openai");

const openAiApiKey = defineSecret("OPENAI_API_KEY");

exports.analyzeMood = onCall({
  secrets: [openAiApiKey],
  invoker: 'public', // Allow unauthenticated App users to call this
}, async (request) => {
  // 1. Get the data from the request
  const { moodHistory, sleepHistory, habits, observations } = request.data;
  const apiKey = openAiApiKey.value();

  if (!apiKey) {
    throw new Error("OpenAI API Key is not set in secrets.");
  }

  const openai = new OpenAI({ apiKey: apiKey });

  // 2. Construct the prompt
  let prompt = "You are an emotional wellness coach. Analyze the following user data to find patterns between sleep, context, habits (signals), and mood.\n";
  prompt += "Provide a daily summary and identify triggers (positive 'Boosters' and negative 'Drainers').\n";
  prompt += "Also note any trends in the user's observations.\n";
  prompt += "Be concise, friendly, and use bullet points.\n\n";

  prompt += "--- SLEEP HISTORY ---\n" + sleepHistory + "\n";
  prompt += "--- HABITS / TRACKERS ---\n" + habits + "\n";
  prompt += "--- OBSERVATIONS ---\n" + observations + "\n";
  prompt += "--- MOOD HISTORY ---\n" + moodHistory + "\n";

  prompt += "\nPlease analyze this data:";

  try {
    const completion = await openai.chat.completions.create({
      model: "gpt-5.2",
      messages: [
        { role: "system", content: "You are a helpful, empathetic data analyst for a mental health app." },
        { role: "user", content: prompt },
      ],
      temperature: 0.7,
    });

    return { result: completion.choices[0].message.content };
  } catch (error) {
    logger.error("OpenAI Error", error);
    throw new Error("Failed to analyze data: " + error.message);
  }
});
