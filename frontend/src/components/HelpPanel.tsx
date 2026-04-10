import React from 'react';
import { Accordion } from '@mantine/core';

interface HelpPanelProps {
  isDarkMode: boolean;
}

export const HelpPanel: React.FC<HelpPanelProps> = ({ isDarkMode }) => {
  return (
    <Accordion defaultValue="getting-started">
      {/* Getting Started */}
      <Accordion.Item value="getting-started">
        <Accordion.Control>
          <span className={`font-semibold text-lg ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>🚀 Getting Started</span>
        </Accordion.Control>
        <Accordion.Panel>
        <div className={`p-4 text-sm space-y-3 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
          <h4 className="font-semibold text-base">👋 Welcome to Autrans!</h4>
          
          <p>
            Autrans is a simple yet powerful tool designed to take the headache out of scheduling with your <s>workers</s> friends.
          </p>
          
          <p>
            In just a few clicks, you can define your time range, list your tasks, and assign available people.
          </p>
          
          <p><strong>Autrans automatically generates an optimized plan where:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Each person will have a fair share of the workload</li>
            <li>- Each person will participate in each task</li>
            <li>- People can take days off, and the workload will be adjusted accordingly</li>
          </ul>
          
          <hr className="my-4 border-gray-300" />
          
          <p><strong>Basic Workflow:</strong></p>
          <ol className="list-decimal list-inside space-y-1 ml-2">
            <li><strong>Configure Settings</strong> (left panel): Set your trip name, dates, and duration</li>
            <li><strong>Define Tasks</strong>: Add the tasks that need to be done (cooking, cleaning, etc.)</li>
            <li><strong>Add Workers</strong>: List all participants and their availability</li>
            <li><strong>Adjust Constraints</strong> (optional): Fine-tune how the schedule is generated</li>
            <li><strong>Click Submit</strong>: Generate your optimized schedule!</li>
            <li><strong>View & Export</strong>: Check the results and export to your calendar</li>
          </ol>
          
          <p><strong>Quick Tips:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Start with the default settings to see how it works</li>
            <li>- The system automatically ensures fairness and task coverage</li>
            <li>- You can customize everything to match your group's needs</li>
          </ul>
        </div>
        </Accordion.Panel>
      </Accordion.Item>

      {/* Understanding Results */}
      <Accordion.Item value="results">
        <Accordion.Control>
          <span className={`font-semibold text-lg ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>📊 Understanding Results</span>
        </Accordion.Control>
        <Accordion.Panel>
        <div className={`p-4 text-sm space-y-3 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
          <h4 className="font-semibold text-base">How to Read Your Schedule</h4>
          
          <p>After clicking Submit, you'll see several views of your schedule:</p>
          
          <p><strong>Schedule Tab</strong> 📅</p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Visual calendar showing who does what each day</li>
            <li>- Color-coded by task for easy reading</li>
            <li>- Shows actual dates and day names</li>
          </ul>
          
          <p><strong>Grid Tab</strong> 📋</p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Table format: Tasks × Days</li>
            <li>- Shows worker assignments for each task/day combination</li>
            <li>- Compact view of the entire schedule</li>
          </ul>
          
          <p><strong>Audit Tab</strong> 📈</p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>Schedule:</strong> Same as Grid tab</li>
            <li>- <strong>Affectation per day:</strong> How many tasks each person does per day</li>
            <li>- <strong>Affectation per task:</strong> How many times each person does each task</li>
            <li>- <strong>Legend:</strong> <code className="bg-gray-100 dark:bg-gray-700 px-1 rounded">*</code> indicates days off were involved</li>
          </ul>
          
          <p><strong>Export Tab</strong> 💾</p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Download as iCalendar (.ics) for Outlook, Google Calendar, Apple Calendar</li>
            <li>- Download as CSV for Excel, Google Sheets</li>
            <li>- Filenames include trip name, date, and duration</li>
          </ul>
        </div>
        </Accordion.Panel>
      </Accordion.Item>

      {/* General Settings */}
      <Accordion.Item value="settings">
        <Accordion.Control>
          <span className={`font-semibold text-lg ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>⚙️ General Settings</span>
        </Accordion.Control>
        <Accordion.Panel>
        <div className={`p-4 text-sm space-y-3 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
          <h4 className="font-semibold text-base">Trip Configuration</h4>
          
          <p><strong>Trip Name</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Give your trip a memorable name</li>
            <li>- Used in exported filenames</li>
            <li>- Example: "Summer Cabin 2026"</li>
          </ul>
          
          <p><strong>Start Date</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- When does your trip begin?</li>
            <li>- Used to generate actual calendar dates</li>
            <li>- Helps with planning and coordination</li>
          </ul>
          
          <p><strong>Duration (days)</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- How many days is your trip?</li>
            <li>- Maximum: 20 days</li>
            <li>- Affects workload distribution</li>
          </ul>
        </div>
        </Accordion.Panel>
      </Accordion.Item>

      {/* Tasks per day */}
      <Accordion.Item value="tasks">
        <Accordion.Control>
          <span className={`font-semibold text-lg ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>📋 Tasks per day</span>
        </Accordion.Control>
        <Accordion.Panel>
        <div className={`p-4 text-sm space-y-3 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
          <h4 className="font-semibold text-base">Defining Your Tasks</h4>
          
          <p><strong>What are Tasks?</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Activities that need to be done during your trip</li>
            <li>- Examples: Cooking, Cleaning, Shopping, Dishes, Trash</li>
            <li>- Each task can require multiple workers</li>
          </ul>
          
          <p><strong>Task Settings:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>Name</strong>: What the task is called</li>
            <li>- <strong>Workers Needed</strong>: How many people are required (e.g., 2 for cooking)</li>
            <li>- <strong>Difficulty</strong>: How challenging or time-consuming the task is (default: 1)</li>
            <li>- <strong>Color</strong>: Visual identifier in the schedule</li>
            <li>- <strong>Range</strong> (optional): Limit task to specific days</li>
          </ul>
          
          <p><strong>Understanding Task Difficulty:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>What it is</strong>: A numeric value representing task complexity/effort</li>
            <li>- <strong>Default</strong>: 1 (standard task)</li>
            <li>- <strong>Higher values</strong>: More challenging or time-consuming tasks</li>
            <li>- <strong>Examples</strong>:
              <ul className="list-none space-y-1 ml-4 mt-1">
                <li>- Difficulty 1: Quick tasks (taking out trash, setting table)</li>
                <li>- Difficulty 2: Standard tasks (cooking simple meal, basic cleaning)</li>
                <li>- Difficulty 3+: Complex tasks (cooking elaborate meal, deep cleaning)</li>
              </ul>
            </li>
          </ul>
          
          <p><strong>How Difficulty Affects Scheduling:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Workload is balanced by <strong>difficulty points</strong>, not just task count</li>
            <li>- Someone doing 3 easy tasks (3 pts) ≈ Someone doing 1 hard task (3 pts)</li>
            <li>- Ensures fair distribution when tasks vary in complexity</li>
            <li>- Audit tables show both count and difficulty points: <code className="bg-gray-100 dark:bg-gray-700 px-1 rounded">3 (7 pts)</code></li>
          </ul>
          
          <p><strong>Tips:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Be specific: "Breakfast" and "Dinner" instead of just "Cooking"</li>
            <li>- Consider task duration: Some tasks need more people</li>
            <li>- Use difficulty to reflect actual effort, not just time</li>
            <li>- Use colors to group related tasks</li>
            <li>- You can have up to 20 tasks</li>
          </ul>
        </div>
        </Accordion.Panel>
      </Accordion.Item>

      {/* Workers & Balance */}
      <Accordion.Item value="workers">
        <Accordion.Control>
          <span className={`font-semibold text-lg ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>👥 Workers & Balance</span>
        </Accordion.Control>
        <Accordion.Panel>
        <div className={`p-4 text-sm space-y-3 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
          <h4 className="font-semibold text-base">Managing Participants</h4>
          
          <p><strong>Adding Workers:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- List everyone participating in the trip</li>
            <li>- Each person can have days off</li>
            <li>- You can have up to 20 workers</li>
          </ul>
          
          <p><strong>Days Off:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Select days when someone is unavailable</li>
            <li>- They won't be assigned tasks on those days</li>
            <li>- Affects workload distribution (see Balance below)</li>
          </ul>
          
          <p><strong>Workload Offset (Optional):</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Compensate for workload imbalances from previous periods</li>
            <li>- <strong>How to use:</strong>
              <ul className="list-none space-y-1 ml-4 mt-1">
                <li>- <strong>Negative</strong> (-1, -2, etc.): Worker worked too much before → Give fewer tasks</li>
                <li>- <strong>Positive</strong> (+1, +2, etc.): Worker worked too little before → Give more tasks</li>
                <li>- <strong>Zero</strong> (0): No adjustment needed</li>
              </ul>
            </li>
            <li>- <strong>When to use:</strong>
              <ul className="list-none space-y-1 ml-4 mt-1">
                <li>- Multi-trip planning (e.g., monthly cabin trips)</li>
                <li>- Compensating for past unfairness</li>
                <li>- Balancing workload across multiple periods</li>
              </ul>
            </li>
          </ul>
          
          <p><strong>Task Preferences (Optional):</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Each worker can rank tasks by preference</li>
            <li>- Use ↑↓ arrows to reorder tasks</li>
            <li>- Tasks at the top = most preferred</li>
            <li>- Scheduler tries to assign preferred tasks when possible</li>
          </ul>
          
          <hr className="my-4 border-gray-300" />
          
          <h4 className="font-semibold text-base">⚖️ Balance Settings - Why It Matters</h4>
          
          <p><strong>"Days off" Balance (Recommended) ✅</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Workers work <strong>proportionally to their available days</strong></li>
            <li>- <strong>Fair</strong>: People with fewer available days do less work</li>
            <li>- <strong>Example</strong>:
              <ul className="list-none space-y-1 ml-4 mt-1">
                <li>- Alice: 7 working days → 100% workload</li>
                <li>- Bob: 5 working days (2 days off) → 71% workload</li>
                <li>- Bob does 71% of Alice's work (5/7 = 0.71)</li>
              </ul>
            </li>
          </ul>
          
          <p><strong>"Ignore days off" Balance</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Everyone works <strong>equally regardless of days off</strong></li>
            <li>- <strong>Equal</strong>: Same total workload for everyone</li>
            <li>- <strong>Example</strong>:
              <ul className="list-none space-y-1 ml-4 mt-1">
                <li>- Alice: 7 working days → 100% workload</li>
                <li>- Bob: 5 working days (2 days off) → 100% workload</li>
                <li>- Bob does the same amount as Alice, but in fewer days</li>
              </ul>
            </li>
          </ul>
          
          <p><strong>When to Use Each:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>Days off</strong>: Most fair for trips where availability varies</li>
            <li>- <strong>Ignore days off</strong>: When you want strict equality regardless of circumstances</li>
          </ul>
        </div>
        </Accordion.Panel>
      </Accordion.Item>

      {/* Advanced Settings - Constraints */}
      <Accordion.Item value="constraints">
        <Accordion.Control>
          <span className={`font-semibold text-lg ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>🔧 Advanced Settings - Constraints</span>
        </Accordion.Control>
        <Accordion.Panel>
        <div className={`p-4 text-sm space-y-3 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
          <h4 className="font-semibold text-base">Understanding Constraints</h4>
          
          <p>
            Constraints are <strong>rules</strong> that govern how your schedule is created. 
            They ensure fairness, respect availability, and meet your requirements.
          </p>
          
          <hr className="my-4 border-gray-300" />
          
          <h5 className="font-semibold">Constraint Status Options</h5>
          
          <p><strong>Hard 🔴</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>MUST be satisfied</strong> for a valid schedule</li>
            <li>- If impossible, the schedule will fail</li>
            <li>- Use for non-negotiable requirements</li>
            <li>- Example: "Tasks must be covered" is typically hard</li>
          </ul>
          
          <p><strong>Soft 🟡</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>Preferred but flexible</strong></li>
            <li>- Can be relaxed if needed to find a solution</li>
            <li>- <strong>Order matters</strong>: Soft constraints earlier in the list = higher priority</li>
            <li>- Use the ↑ button to reorder soft constraints</li>
          </ul>
          
          <p><strong>Off ⚪</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Constraint is disabled and not applied</li>
            <li>- Use when you don't want this rule enforced</li>
          </ul>
          
          <hr className="my-4 border-gray-300" />
          
          <h5 className="font-semibold">Available Constraints</h5>
          
          <p><strong>Task Coverage 📋</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>What</strong>: Each task has the required number of workers</li>
            <li>- <strong>Why</strong>: Ensures all work gets done</li>
            <li>- <strong>Example</strong>: If "Cooking" needs 2 people, exactly 2 are assigned</li>
          </ul>
          
          <p><strong>No Consecutive Tasks 🚫</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>What</strong>: Workers do at most one task per day</li>
            <li>- <strong>Why</strong>: Prevents burnout and overwork</li>
            <li>- <strong>Example</strong>: Alice does Cooking OR Cleaning, not both</li>
          </ul>
          
          <p><strong>Days Off 🏖️</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>What</strong>: Workers cannot work on their days off</li>
            <li>- <strong>Why</strong>: Respects personal plans and availability</li>
            <li>- <strong>Example</strong>: Bob has Monday off, so he's not assigned Monday tasks</li>
          </ul>
          
          <p><strong>Overall Equity ⚖️</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>What</strong>: Fair distribution of total workload</li>
            <li>- <strong>Why</strong>: Ensures no one is overworked</li>
            <li>- <strong>Example</strong>: Over 7 days, everyone does 6-8 tasks (not 2 vs 12)</li>
          </ul>
          
          <p><strong>Daily Equity 📅</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>What</strong>: Similar amount of work each day</li>
            <li>- <strong>Why</strong>: Prevents exhausting days</li>
            <li>- <strong>Example</strong>: No one does 3 tasks in one day while others do 0</li>
          </ul>
          
          <p><strong>Task Diversity 🎯</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>What</strong>: Everyone participates in each task type</li>
            <li>- <strong>Why</strong>: Variety and skill sharing</li>
            <li>- <strong>Example</strong>: Everyone cooks at least once, not just 2 people cooking all week</li>
          </ul>
          
          <p><strong>Worker Preference 💭</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>What</strong>: Respect worker task preferences</li>
            <li>- <strong>Why</strong>: Improves satisfaction</li>
            <li>- <strong>Note</strong>: Requires preferences to be set for workers</li>
          </ul>
          
          <p><strong>One Task Per Day 1️⃣</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>What</strong>: Workers can do at most 1 task per day (stricter than No Consecutive Tasks)</li>
            <li>- <strong>Why</strong>: Maximum fairness and rest</li>
          </ul>
          
          <hr className="my-4 border-gray-300" />
          
          <p><strong>Recommended Starting Point:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>Hard</strong>: Task Coverage, No Consecutive Tasks, Days Off</li>
            <li>- <strong>Soft</strong>: Overall Equity, Daily Equity, Task Diversity</li>
          </ul>
        </div>
        </Accordion.Panel>
      </Accordion.Item>

      {/* Tips & Tricks */}
      <Accordion.Item value="tips">
        <Accordion.Control>
          <span className={`font-semibold text-lg ${isDarkMode ? 'text-gray-100' : 'text-gray-900'}`}>💡 Tips & Tricks</span>
        </Accordion.Control>
        <Accordion.Panel>
        <div className={`p-4 text-sm space-y-3 ${isDarkMode ? 'text-gray-300' : 'text-gray-700'}`}>
          <h4 className="font-semibold text-base">Getting the Best Results</h4>
          
          <p><strong>For Feasible Schedules:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Ensure enough workers for your tasks</li>
            <li>- Don't over-constrain (too many hard constraints)</li>
            <li>- Check capacity: (tasks × workers needed × days) ≤ (workers × available days)</li>
          </ul>
          
          <p><strong>For Fair Schedules:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Use "Days off" balance mode</li>
            <li>- Keep Overall Equity as a constraint</li>
            <li>- Enable Task Diversity</li>
          </ul>
          
          <p><strong>For Flexible Schedules:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Use more soft constraints</li>
            <li>- Make "No Consecutive Tasks" soft</li>
            <li>- Adjust constraint priorities</li>
          </ul>
          
          <p><strong>Troubleshooting:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- <strong>"Schedule not feasible"</strong>: Reduce hard constraints or add more workers</li>
            <li>- <strong>Unfair distribution</strong>: Check balance mode and equity constraints</li>
            <li>- <strong>Someone overworked</strong>: Enable Daily Equity constraint</li>
            <li>- <strong>Tasks not covered</strong>: Ensure Task Coverage is enabled</li>
          </ul>
          
          <p><strong>State Management:</strong></p>
          <ul className="list-none space-y-1 ml-4">
            <li>- Use "Generate State Code" to save your configuration</li>
            <li>- Share the state code with your group</li>
            <li>- Use "Load State" to restore a saved configuration</li>
          </ul>
        </div>
        </Accordion.Panel>
      </Accordion.Item>
    </Accordion>
  );
};
