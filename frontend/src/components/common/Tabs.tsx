import React, { useState } from 'react';

interface Tab {
  id: string;
  label: string;
  icon?: string;
  content: React.ReactNode;
}

interface TabsProps {
  tabs: Tab[];
  defaultTab?: string;
  onChange?: (tabId: string) => void;
  isDarkMode?: boolean;
}

export const Tabs: React.FC<TabsProps> = ({ tabs, defaultTab, onChange, isDarkMode = false }) => {
  const [activeTab, setActiveTab] = useState(defaultTab || tabs[0]?.id || '');

  const handleTabChange = (tabId: string) => {
    setActiveTab(tabId);
    onChange?.(tabId);
  };

  const activeTabContent = tabs.find(tab => tab.id === activeTab)?.content;

  return (
    <div className="w-full">
      {/* Tab Headers */}
      <div className={`border-b ${isDarkMode ? 'border-gray-700' : 'border-gray-200'}`}>
        <div className="flex gap-1 overflow-x-auto">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => handleTabChange(tab.id)}
              className={`px-4 py-3 font-medium text-sm whitespace-nowrap transition-colors border-b-2 ${
                activeTab === tab.id
                  ? `${isDarkMode ? 'border-primary-400 text-primary-400' : 'border-primary-500 text-primary-600'}`
                  : `border-transparent ${isDarkMode ? 'text-gray-400 hover:text-gray-200 hover:border-gray-600' : 'text-gray-600 hover:text-gray-900 hover:border-gray-300'}`
              }`}
            >
              {tab.icon && <span className="mr-2">{tab.icon}</span>}
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Tab Content */}
      <div className="mt-4">
        {activeTabContent}
      </div>
    </div>
  );
};

interface SimpleTabsProps {
  tabs: Array<{ label: string; content: React.ReactNode }>;
}

export const SimpleTabs: React.FC<SimpleTabsProps> = ({ tabs }) => {
  const tabsWithIds = tabs.map((tab, index) => ({
    id: `tab-${index}`,
    label: tab.label,
    content: tab.content,
  }));

  return <Tabs tabs={tabsWithIds} />;
};